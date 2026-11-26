import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const NiloApp());

const kGreen = Color(0xFFD9A441);
const kBg = Color(0xFF16191D);

class NiloApp extends StatelessWidget {
  const NiloApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'نيلو Nilo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: kBg,
            colorScheme: const ColorScheme.dark(primary: kGreen)),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const ModeGate(),
      );
}

const kSite = 'https://nilo-eg.vercel.app';
const kModes = [
  ['chat', 'chat', 'دردشة نيلو', 'اسأل واتكلم مع نيلو'],
  ['sales', 'sales', 'مبيعات', 'غرفة المبيعات والعملاء'],
  ['tr', 'tr', 'ترجمة', 'ترجمة نص وفويس ومحادثة'],
];

class ModeGate extends StatefulWidget {
  const ModeGate({super.key});
  @override
  State<ModeGate> createState() => _ModeGateState();
}

class _ModeGateState extends State<ModeGate> {
  String? mode;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() { mode = p.getString('mode'); ready = true; });
    });
  }

  Future<void> pick(String m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('mode', m);
    if (m == 'chat') {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ChatPage()));
    } else {
      setState(() => mode = m);
      await launchUrl(Uri.parse(m == 'sales' ? '$kSite/?sales=1' : '$kSite/translate.html'), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (mode == 'chat') return const ChatPage();
    return Scaffold(
      appBar: AppBar(title: const Text('نيلو Nilo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('محتاج إيه دلوقتي؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('هنفتحلك الشاشة دي بس، ومش هنفكرك بالباقي. تقدر تبدّل في أي وقت.', style: TextStyle(fontSize: 13, color: Colors.white60)),
          const SizedBox(height: 16),
          for (final m in kModes)
            Card(
              color: mode == m[0] ? const Color(0xFF2A2F36) : const Color(0xFF1F2328),
              child: ListTile(
                leading: Icon(m[1] == 'chat' ? Icons.chat_bubble_outline : m[1] == 'sales' ? Icons.show_chart : Icons.translate, size: 28, color: kGreen),
                title: Text(m[2]),
                subtitle: Text(m[3]),
                trailing: mode == m[0] ? const Text('آخر اختيار', style: TextStyle(fontSize: 12, color: Colors.white54)) : null,
                onTap: () => pick(m[0]),
              ),
            ),
          const Spacer(),
          const Center(child: Text('تطبيق مصري خالص', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          const Center(child: Text('صُنع بواسطة Mohamed Mostafa', style: TextStyle(fontSize: 13, color: Colors.white60))),
          const SizedBox(height: 2),
          const Center(child: Text('بيشتغل بنموذج Gemini المجاني. الترجمة الآلية ممكن تغلط.', style: TextStyle(fontSize: 11, color: Colors.white38))),
        ]),
      ),
    );
  }
}

class Msg {
  final bool user;
  final String text;
  final String? link;
  final List<List<String>> srcs;
  final String? img;
  String? q;
  String? fbDone;
  Msg(this.user, this.text, {this.link, this.srcs = const [], this.img, this.q});
  Map<String, dynamic> toJson() => {'u': user, 't': text, 'l': link, 's': srcs, 'i': img};
  static Msg fromJson(Map<String, dynamic> j) => Msg(j['u'] == true, j['t'] as String, link: j['l'] as String?, srcs: ((j['s'] as List?) ?? []).map((e) => List<String>.from(e)).toList(), img: j['i'] as String?);
}

class Conv {
  String id;
  String title;
  List<Msg> msgs;
  Conv(this.id, this.title, this.msgs);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const greet = 'يا أهلاً! أنا نيلو، صاحبك اللي فاهم مصر. اسألني في أي حاجة: ورق حكومي، فواتير، جيش، أسعار، شغل. اكتب عربي أو فرانكو أو دوس على المايك.';
  List<Msg> msgs = [Msg(false, greet)];
  final convs = <Conv>[];
  Conv? cur;
  List<String> mem = [];
  SharedPreferences? prefs;

  Future<void> loadAll() async {
    prefs = await SharedPreferences.getInstance();
    mem = prefs!.getStringList('mem') ?? [];
    final raw = prefs!.getString('convs');
    if (raw != null) {
      for (final c in jsonDecode(raw) as List) {
        convs.add(Conv(c['id'], c['title'], (c['m'] as List).map((e) => Msg.fromJson(Map<String, dynamic>.from(e))).toList()));
      }
    }
    newConv();
  }

  void newConv() {
    final c = Conv(DateTime.now().millisecondsSinceEpoch.toString(), 'محادثة جديدة', [Msg(false, greet)]);
    convs.insert(0, c);
    cur = c;
    msgs = c.msgs;
    if (mounted) setState(() {});
  }

  void persist() {
    if (cur != null && cur!.title == 'محادثة جديدة') {
      final f = msgs.where((m) => m.user);
      if (f.isNotEmpty) cur!.title = f.first.text.length > 36 ? f.first.text.substring(0, 36) : f.first.text;
    }
    final keep = convs.where((c) => c.msgs.any((m) => m.user)).take(30).map((c) => {'id': c.id, 'title': c.title, 'm': c.msgs.map((m) => m.toJson()).toList()}).toList();
    prefs?.setString('convs', jsonEncode(keep));
  }

  final ctrl = TextEditingController();
  final scroll = ScrollController();
  final stt = SpeechToText();
  final tts = FlutterTts();
  final player = AudioPlayer();
  String? pendImg;
  bool sttOk = false, hands = false, wake = true, busy = false, speak = true;
  String status = '';

  @override
  void initState() {
    super.initState();
    loadAll();
    initTts();
    tts.awaitSpeakCompletion(true);
    stt.initialize(onError: (e) {
      if (hands && !busy) Future.delayed(const Duration(milliseconds: 600), listen);
    }, onStatus: (s) {
      if ((s == 'done' || s == 'notListening') && hands && !busy) {
        Future.delayed(const Duration(milliseconds: 400), listen);
      }
    }).then((v) => setState(() => sttOk = v));
  }

  String nd(String t) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var o = t;
    for (var i = 0; i < 10; i++) {
      o = o.replaceAll(ar[i], '$i');
    }
    return o;
  }

  Msg? local(String t0) {
    final t = nd(t0.trim()).replaceAll(RegExp(r'[؟?!.,،]+$'), '');
    final now = DateTime.now();
    var mm = RegExp(r'^(?:افتكر|اعرف|خليك فاكر)\s+(?:اني|إني|ان|أن)?\s*(.+)$').firstMatch(t);
    if (mm != null) {
      mem.add(mm.group(1)!);
      if (mem.length > 30) mem = mem.sublist(mem.length - 30);
      prefs?.setStringList('mem', mem);
      return Msg(false, 'تمام، هفتكر إن ${mm.group(1)}. المعلومة محفوظة على موبايلك بس.');
    }
    if (RegExp(r'^(انت فاكر ايه عني|ايه اللي فاكره عني|فاكر ايه)').hasMatch(t)) {
      return Msg(false, mem.isEmpty ? 'لسه مفيش حاجة محفوظة. قولي "افتكر إني ..."' : 'فاكر عنك: ${mem.join('، ')}');
    }
    if (RegExp(r'^(انسى كل حاجة|امسح الذاكرة)').hasMatch(t)) {
      mem = [];
      prefs?.setStringList('mem', mem);
      return Msg(false, 'تمام، مسحت كل اللي كنت فاكره عنك.');
    }
    if (RegExp(r'^(الساعة كام|الساعه كام|كام الساعة)').hasMatch(t)) {
      return Msg(false,
          'الساعة دلوقتي ${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'مساءً' : 'صباحاً'}');
    }
    var m = RegExp(r'^فكرني (?:بعد )?(\d+|ربع|نص|ساعة|دقيقة)\s*(ساعة|ساعات|دقيقة|دقايق|دقيقه|ساعه)?\s*(?:اني|إني|ان)?\s*(.*)$').firstMatch(t);
    if (m != null) {
      var n = 0;
      var unit = m.group(2) ?? '';
      var what = (m.group(3) ?? '').trim();
      final g = m.group(1)!;
      if (g == 'ربع') { n = 15; unit = 'دقيقة'; }
      else if (g == 'نص') { n = 30; unit = 'دقيقة'; }
      else if (g == 'ساعة') { n = 1; unit = 'ساعة'; }
      else if (g == 'دقيقة') { n = 1; unit = 'دقيقة'; }
      else { n = int.parse(g); }
      if (n > 0 && unit.isNotEmpty) {
        final d = unit.contains('ساع') ? Duration(hours: n) : Duration(minutes: n);
        if (what.isEmpty) what = 'الميعاد بتاعك';
        Timer(d, () {
          final s = 'فكرتك: $what';
          if (mounted) setState(() => msgs.add(Msg(false, '⏰ $s')));
          speakText(s);
        });
        return Msg(false, 'حاضر، هفكرك $what بعد $n $unit. سيب التطبيق شغال.');
      }
    }
    m = RegExp(r'^(?:احسب\s+)?([\d\s.+\-*/x×÷()]+)$').firstMatch(t);
    if (m != null && RegExp(r'\d\s*[+\-*/x×÷]\s*\(?\d').hasMatch(t)) {
      final r = calc(m.group(1)!.replaceAll('x', '*').replaceAll('×', '*').replaceAll('÷', '/'));
      if (r != null) return Msg(false, 'الناتج ${r == r.roundToDouble() ? r.toInt() : double.parse(r.toStringAsFixed(6))}');
    }
    m = RegExp(r'^(?:كلم|اتصل ب|رن على)\s*([\d\s+]{8,})$').firstMatch(t);
    if (m != null) {
      final p = m.group(1)!.replaceAll(' ', '');
      return Msg(false, 'دوس على الرابط عشان تتصل بـ $p', link: 'tel:$p');
    }
    m = RegExp(r'^(?:ابعت|ابعتله)\s*(?:واتساب\s*)?(?:ل|لـ)?\s*(\+?\d[\d\s]{8,}?)\s+(.+)$').firstMatch(t);
    if (m != null) {
      var p = m.group(1)!.replaceAll(' ', '').replaceAll('+', '');
      if (p.startsWith('01')) p = '2$p';
      return Msg(false, 'جاهز. دوس على الرابط وهيفتح واتساب بالرسالة وانت اللي تدوس إرسال.',
          link: 'https://wa.me/$p?text=${Uri.encodeComponent(m.group(2)!)}');
    }
    const sites = {'يوتيوب': 'https://youtube.com', 'جوجل': 'https://google.com', 'خرائط': 'https://maps.google.com', 'بوابة مصر الرقمية': 'https://digital.gov.eg'};
    m = RegExp(r'^(?:افتح|وديني على)\s+(.+)$').firstMatch(t);
    if (m != null) {
      for (final k in sites.keys) {
        if (m.group(1)!.contains(k)) return Msg(false, 'حاضر، دوس عشان تفتح $k', link: sites[k]);
      }
    }
    return null;
  }

  // tiny safe + - * / parser
  double? calc(String s) {
    final src = s.replaceAll(' ', '');
    var i = 0;
    late double? Function() term;
    late double? Function() fac;
    double? expr() {
      var v = term();
      while (v != null && i < src.length && (src[i] == '+' || src[i] == '-')) {
        final op = src[i++];
        final r = term();
        if (r == null) return null;
        v = op == '+' ? v + r : v - r;
      }
      return v;
    }
    term = () {
      var v = fac();
      while (v != null && i < src.length && (src[i] == '*' || src[i] == '/')) {
        final op = src[i++];
        final r = fac();
        if (r == null) return null;
        v = op == '*' ? v * r : v / r;
      }
      return v;
    };
    fac = () {
      if (i < src.length && src[i] == '(') {
        i++;
        final v = expr();
        if (i < src.length && src[i] == ')') i++;
        return v;
      }
      final st = i;
      if (i < src.length && src[i] == '-') i++;
      while (i < src.length && RegExp(r'[\d.]').hasMatch(src[i])) { i++; }
      return double.tryParse(src.substring(st, i));
    };
    final r = expr();
    return (r != null && i == src.length && r.isFinite) ? r : null;
  }

  String sys() {
    final n = DateTime.now();
    return 'انت "نيلو" (Nilo)، مساعد ذكي مصري صميم، صاحب المستخدم. دمك خفيف ودافي وبتتكلم بالعامية المصرية الطبيعية (مش فصحى ومش ترجمة حرفية). لو المستخدم كتب فرانكو/Arabizi رد بنفس الأسلوب. خليك مختصر وواضح وخطوات مرقمة للإجراءات. تخصصك الحياة في مصر: أوراق حكومية، فواتير، تجنيد، جامعات، شغل، ضرايب، أسعار بالجنيه، وأي سؤال عام. أمانة: الأسعار والرسوم والقوانين بتتغير، ماتخترعش أرقام أو لينكات؛ لو مش متأكد قول كده وانصحه يتأكد من الجهة الرسمية (بوابة مصر الرقمية digital.gov.eg). في المواضيع الرسمية اختم بـ "اتأكد من الجهة الرسمية قبل ما تتحرك." ${mem.isEmpty ? '' : 'معلومات اتقال إنها عن المستخدم (استخدمها بطبيعية لو مناسبة بس): ${mem.join('؛ ')}. '}التاريخ والوقت دلوقتي: $n';
  }

  Future<void> initTts() async {
    await tts.setLanguage('ar-EG');
    try {
      final vs = await tts.getVoices as List;
      Map? best; int bs = -1;
      for (final v in vs) {
        final m = Map.from(v as Map);
        final loc = (m['locale'] ?? '').toString().replaceAll('_', '-').toLowerCase();
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (!loc.startsWith('ar')) continue;
        var sc = (loc == 'ar-eg' ? 100 : 0) + (name.contains('network') ? 20 : 0) + (name.contains('x-') ? 5 : 0);
        if (sc > bs) { bs = sc; best = m; }
      }
      if (best != null) await tts.setVoice({'name': best['name'].toString(), 'locale': best['locale'].toString()});
    } catch (_) {}
    await tts.setSpeechRate(0.47);
    await tts.setPitch(1.0);
  }

  Future<void> pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
      if (x == null) return;
      final b = await x.readAsBytes();
      setState(() { pendImg = base64Encode(b); if (ctrl.text.isEmpty) ctrl.text = 'اشرحلي الصورة دي بالمصري وقولي أعمل ايه'; });
    } catch (_) {}
  }

  Future<void> sendFb(Msg m, String r) async {
    setState(() => m.fbDone = r);
    try {
      await http.post(Uri.parse('https://nilo-eg.vercel.app/api/feedback'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'rating': r, 'q': m.q ?? '', 'a': m.text})).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<bool> neuralSpeak(String t) async {
    try {
      final r = await http.post(Uri.parse('https://nilo-eg.vercel.app/api/tts'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'text': t})).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final a = j['audio'] as String?;
      if (a == null || !hands) return a != null;
      final done = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) { if (!done.isCompleted) done.complete(); });
      await player.play(BytesSource(base64Decode(a), mimeType: 'audio/wav'));
      await done.future.timeout(const Duration(seconds: 60), onTimeout: () {});
      await sub.cancel();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Msg?> special(String t) async {
    const base = 'https://nilo-eg.vercel.app';
    if (RegExp(r'(ارسم|رسم|اعمل.{0,12}(صورة|صوره)|صمم.{0,12}(صورة|صوره|لوجو)|ولد.{0,8}(صورة|صوره)|لوجو)').hasMatch(t)) {
      try {
        final r = await http.post(Uri.parse('$base/api/gen'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'mode': 'img', 'prompt': t, 'mem': mem})).timeout(const Duration(seconds: 40));
        final p = jsonDecode(utf8.decode(r.bodyBytes))['prompt'] as String;
        final u = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(p)}?width=768&height=768&nologo=true&seed=${DateTime.now().millisecondsSinceEpoch % 1000000}';
        return Msg(false, 'اتفضل الصورة (دوس عليها تفتحها).', img: u, link: u);
      } catch (_) {
        return Msg(false, 'معرفتش أعمل الصورة دلوقتي، جرب تاني كمان شوية.');
      }
    }
    if (RegExp(r'(بوربوينت|باوربوينت|بور بوينت|powerpoint|pptx|عرض تقديمي|presentation|سلايدات|slides)', caseSensitive: false).hasMatch(t) ||
        (RegExp(r'(pdf|بي دي اف|وورد|word|docx|ملف|مستند|تقرير|سي في|\bcv\b|سيرة ذاتية|خطاب)', caseSensitive: false).hasMatch(t) && RegExp(r'(اعمل|اكتب|جهز|حضر|عايز|اطلع|make|create|write)', caseSensitive: false).hasMatch(t))) {
      final u = '$base/?q=${Uri.encodeComponent(t)}';
      return Msg(false, 'الملفات (PowerPoint/Word/PDF) بتتجهز وتتحمل من صفحة نيلو على المتصفح. دوس "افتح" وهيجهزهالك هناك.', link: u);
    }
    if (RegExp(r'((دور|ابحث|لاقي|قدملي|قدم)\S*.{0,15}(شغل|وظيف)|مساعد الشغل|job)', caseSensitive: false).hasMatch(t)) {
      return Msg(false, 'مساعد الشغل (بحث وظايف، تقديم جاهز، متابعة طلباتك) على صفحة نيلو في المتصفح. دوس "افتح".', link: '$base/?jobs=1');
    }
    if (RegExp(r'(غرفة المبيعات|متابعة عملاء|متابعة العملاء|جدول عملاء|ادارة العملاء|إدارة العملاء|crm)', caseSensitive: false).hasMatch(t)) {
      return Msg(false, 'غرفة المبيعات (عملاء، متابعات، ردود جاهزة على الاعتراضات، تحليل محادثة) على صفحة نيلو. دوس "افتح".', link: '$base/?sales=1');
    }
    if (RegExp(r'(خطة تسويق|استراتيجية تسويق|تقويم محتوى|حملة اعلان|حملة إعلان|نصوص اعلان|سكريبت مبيعات|رسائل مبيعات|شركة تسويق|شركة مبيعات|الرد على الاعتراضات)').hasMatch(t)) {
      return Msg(false, 'قسم شركة التسويق والمبيعات (استراتيجية، محتوى، إعلانات، سكريبتات، عروض) على صفحة نيلو في المتصفح. دوس "افتح".', link: '$base/?co=1');
    }
    return null;
  }

  Future<void> speakText(String t) async {
    if (!hands) return;
    await tts.stop();
    await player.stop();
    if (await neuralSpeak(t)) return;
    final clean = t.replaceAll(RegExp(r'https?://\S+'), '').replaceAll(RegExp(r'[*#_`>\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final c = clean.length > 600 ? clean.substring(0, 600) : clean;
    for (final p in RegExp(r'[^.!؟?،\n]+[.!؟?\n]?').allMatches(c).map((m) => m.group(0)!.trim()).where((x) => x.isNotEmpty)) {
      if (!hands) break;
      await tts.speak(p);
    }
  }

  Future<void> send(String t) async {
    t = t.trim();
    if (t.isEmpty) return;
    ctrl.clear();
    setState(() { msgs.add(Msg(true, t)); busy = true; status = 'بفكر…'; });
    toBottom();
    final l = local(t) ?? await special(t);
    String reply;
    if (l != null) {
      setState(() => msgs.add(l));
      reply = l.text;
    } else {
      final hist = msgs.where((m) => m.link == null).toList();
      final tail = hist.length > 12 ? hist.sublist(hist.length - 12) : hist;
      var srcs = <List<String>>[];
      final sentImg = pendImg != null;
      try {
        final r = await http.post(Uri.parse('https://nilo-eg.vercel.app/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': tail.map((m) => {'role': m.user ? 'user' : 'assistant', 'content': m.text}).toList(),
              'mem': mem,
              if (pendImg != null) 'image': {'mime': 'image/jpeg', 'data': pendImg}
            })).timeout(const Duration(seconds: 60));
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        reply = (j['text'] as String).trim();
        pendImg = null;
        srcs = ((j['sources'] as List?) ?? []).map((e) => [e['title'] as String, e['url'] as String]).toList();
      } catch (e) {
        reply = 'حصلت مشكلة في الاتصال، جرب تاني كمان شوية.';
      }
      setState(() => msgs.add(Msg(false, reply, srcs: srcs, q: t)));
    }
    persist();
    toBottom();
    await speakText(reply);
    setState(() { busy = false; status = ''; });
    if (hands) listen();
  }

  void toBottom() => Future.delayed(const Duration(milliseconds: 100), () {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  final wakeRe = RegExp(r'(يا\s*)?(نيلو|نايلو|نيلا|nilo)', caseSensitive: false);

  Future<void> listen() async {
    if (!sttOk || busy || stt.isListening) return;
    setState(() => status = hands && wake ? 'سامعك… قول "يا نيلو" وبعدها طلبك' : 'سامعك… اتكلم');
    await stt.listen(
        localeId: 'ar_EG',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (r) async {
          if (!r.finalResult) return;
          var t = r.recognizedWords.trim();
          if (t.isEmpty) return;
          if (hands && wake) {
            if (!wakeRe.hasMatch(t)) { setState(() => status = 'مستني "يا نيلو"…'); return; }
            t = t.replaceFirst(wakeRe, '').trim();
            if (t.isEmpty) { await speakText('أيوه، سامعك'); return; }
          }
          send(t);
        });
  }

  Future<void> openLink(String u) async {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1F2328),
        child: SafeArea(
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                    onPressed: () { newConv(); Navigator.pop(context); },
                    icon: const Icon(Icons.add),
                    label: const Text('محادثة جديدة'))),
            Expanded(
                child: ListView(children: [
              for (final c in convs.where((c) => c.msgs.any((m) => m.user) || c == cur))
                ListTile(
                  selected: c == cur,
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() { convs.remove(c); if (c == cur) newConv(); }); persist(); }),
                  onTap: () { setState(() { cur = c; msgs = c.msgs; }); Navigator.pop(context); toBottom(); },
                ),
            ])),
          ]),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13261F),
        title: const Text('نيلو  Nilo', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5)),
        actions: [
          IconButton(tooltip: 'غرفة المبيعات', icon: const Icon(Icons.trending_up), onPressed: () => openLink('https://nilo-eg.vercel.app/?sales=1')),
          IconButton(tooltip: 'شركة تسويق ومبيعات', icon: const Icon(Icons.storefront_outlined), onPressed: () => openLink('https://nilo-eg.vercel.app/?co=1')),
          IconButton(tooltip: 'تبديل الوضع', icon: const Icon(Icons.apps), onPressed: () async { final p = await SharedPreferences.getInstance(); await p.remove('mode'); if (!mounted) return; Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ModeGate())); }),
          IconButton(tooltip: 'مترجم', icon: const Icon(Icons.translate), onPressed: () => openLink('https://nilo-eg.vercel.app/translate.html')),
          IconButton(tooltip: 'مساعد الشغل', icon: const Icon(Icons.work_outline), onPressed: () => openLink('https://nilo-eg.vercel.app/?jobs=1')),
          TextButton.icon(
              onPressed: !sttOk ? null : () {
                setState(() { hands = !hands; wake = true; });
                if (hands) { listen(); } else { stt.stop(); tts.stop(); player.stop(); setState(() => status = ''); }
              },
              icon: Icon(hands ? Icons.mic : Icons.mic_none, color: hands ? kGreen : null),
              label: Text('مكالمة', style: TextStyle(color: hands ? kGreen : null))),
        ],
      ),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (c, i) {
                  final m = msgs[i];
                  return Align(
                    alignment: m.user ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .85),
                      decoration: BoxDecoration(color: m.user ? kGreen : const Color(0xFF1A2F27), borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (m.img != null) GestureDetector(onTap: () => openLink(m.img!), child: Padding(padding: const EdgeInsets.only(bottom: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(m.img!, loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())), errorBuilder: (c, e, st) => const Text('الصورة ماطلعتش'))))),
                        SelectableText(m.text, style: const TextStyle(height: 1.6, fontSize: 16)),
                        if (!m.user && m.q != null) Row(children: [
                          if (m.fbDone != null) Text(m.fbDone == 'up' ? 'شكرا 🙏' : 'شكرا، هتحسن 🙏', style: const TextStyle(fontSize: 12, color: Color(0xFFA6CDBB))) else ...[
                            IconButton(visualDensity: VisualDensity.compact, icon: const Text('👍'), onPressed: () => sendFb(m, 'up')),
                            IconButton(visualDensity: VisualDensity.compact, icon: const Text('👎'), onPressed: () => sendFb(m, 'down')),
                          ]
                        ]),
                        if (m.link != null) TextButton(onPressed: () => openLink(m.link!), child: const Text('افتح ↗')),
                        if (m.srcs.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('المصادر:', style: TextStyle(fontSize: 12, color: Color(0xFFA6CDBB)))),
                        for (final sr in m.srcs) InkWell(onTap: () => openLink(sr[1]), child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('🔗 ${sr[0]}', style: const TextStyle(fontSize: 13, color: Color(0xFF8FE0B9), decoration: TextDecoration.underline)))),
                      ]),
                    ),
                  );
                })),
        if (status.isNotEmpty) Padding(padding: const EdgeInsets.all(4), child: Text(status, style: const TextStyle(color: Color(0xFFA6CDBB)))),
        if (hands)
          GestureDetector(
            onTap: () { setState(() => wake = !wake); stt.stop(); Future.delayed(const Duration(milliseconds: 300), listen); },
            child: Container(
              width: 84, height: 84, margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? const Color(0xFF2D7BE5) : kGreen),
              child: const Icon(Icons.mic, size: 40),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton(icon: Icon(Icons.photo_camera_outlined, color: pendImg != null ? kGreen : null), onPressed: pickImage),
              IconButton(icon: const Icon(Icons.mic), onPressed: !sttOk ? null : () { tts.stop(); listen(); }),
              Expanded(child: TextField(controller: ctrl, onSubmitted: send, decoration: InputDecoration(hintText: 'اكتب أو اتكلم…', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
              const SizedBox(width: 6),
              FilledButton(onPressed: () => send(ctrl.text), child: const Text('ابعت')),
            ]),
          ),
        ),
      ]),
    );
  }
}
