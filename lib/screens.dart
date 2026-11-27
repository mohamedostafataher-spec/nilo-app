import 'i18n.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'main.dart';
import 'extras.dart';
import 'bottles.dart';
import 'world.dart';
import 'net.dart';
import 'phrasebook.dart';
import 'talk.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(L(m))));
Future<void> openUrl(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);

class LangDrop extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool auto;
  const LangDrop({super.key, required this.value, required this.onChanged, this.auto = false});
  @override
  Widget build(BuildContext context) => DropdownButton<String>(
        value: value,
        isExpanded: true,
        items: [
          if (auto) DropdownMenuItem(value: 'auto', child: Text(L('تلقائي Auto'))),
          for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(kNames[i])),
        ],
        onChanged: (v) { if (v != null) onChanged(v); },
      );
}

Future<void> saveTr(String o, String t, String to) async {
  final p = await SharedPreferences.getInstance();
  final l = (jsonDecode(p.getString('saved') ?? '[]') as List).cast<Map<String, dynamic>>().toList();
  l.insert(0, {'o': o, 't': t, 'l': to});
  await p.setString('saved', jsonEncode(l.take(200).toList()));
}

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> l = [];
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => l = (jsonDecode(p.getString('saved') ?? '[]') as List).cast<Map<String, dynamic>>().toList());
    });
  }

  Future<void> _del(int i) async {
    final p = await SharedPreferences.getInstance();
    setState(() => l.removeAt(i));
    await p.setString('saved', jsonEncode(l));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Saved • المحفوظات')), backgroundColor: kBg),
        body: l.isEmpty
            ? Center(child: Padding(padding: EdgeInsets.all(24), child: Text(L('لسه مفيش حاجة محفوظة. دوس النجمة تحت أي ترجمة وهتلاقيها هنا، وتشتغل من غير نت (النص بس، الصوت من الجهاز).'), textAlign: TextAlign.center)))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (var i = 0; i < l.length; i++)
                  Card(
                    color: const Color(0xFF12304D),
                    child: ListTile(
                      title: Text(l[i]['t'].toString(), style: const TextStyle(fontSize: 19)),
                      subtitle: Text(l[i]['o'].toString()),
                      leading: IconButton(icon: const Icon(Icons.volume_up), onPressed: () => speak(l[i]['t'].toString(), l[i]['l'].toString())),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _del(i)),
                    ),
                  ),
              ]),
      );
}

class ResultCard extends StatelessWidget {
  final TrResult r;
  final String to;
  const ResultCard({super.key, required this.r, required this.to});
  @override
  Widget build(BuildContext context) {
    if (r.translation.isEmpty) {
      return Padding(padding: EdgeInsets.all(8), child: Text('⚠ ${r.error.isEmpty ? L('مفيش نتيجة') : r.error}', style: TextStyle(color: Colors.orangeAccent)));
    }
    return Card(
      color: const Color(0xFF12304D),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.original.isNotEmpty) Text(r.original, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 6),
          SelectableText(r.translation, style: const TextStyle(fontSize: 20)),
          if (r.rom.isNotEmpty) Text(r.rom, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (r.note.isNotEmpty) Text(r.note, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Row(children: [
            IconButton(icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: r.translation)); toast(context, 'اتنسخت'); }),
            IconButton(icon: const Icon(Icons.volume_up), onPressed: () async { if (!await speak(r.translation, to) && context.mounted) toast(context, 'الجهاز مفيهوش صوت للغة دي'); }),
            IconButton(icon: const Icon(Icons.star_border), onPressed: () async { await saveTr(r.original, r.translation, to); if (context.mounted) toast(context, 'اتحفظت في المحفوظات'); }),
          ]),
          Text(L('ترجمة آلية: ممكن تغلط'), style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
    );
  }
}

// ---------------- Home ----------------
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final hubs = <List<Object>>[
      ['Translation hub', 'ترجمة: نص، فويس، مكالمة، كاميرا، وجهاً لوجه', Icons.translate, [
        ['Translate', 'ترجمة 52 لغة (نص وفويس)', Icons.translate, () => const TranslatePage()],
        ['Live talk', 'مكالمة مترجمة بين موبايلين', Icons.headset_mic, () => const TalkPage()],
        ['Face to face', 'وجهاً لوجه', Icons.people, () => const FacePage()],
        ['Camera', 'منيو ولافتات', Icons.photo_camera, () => const CameraPage()],
        ['Floating button', 'زر عايم للترجمة (خطوات التفعيل)', Icons.bubble_chart, () => const FloatPage()],
        ['App audio capture', 'ترجمة صوت التطبيقات (أندرويد 10+)', Icons.graphic_eq, () => const CapturePage()],
        ['Saved', 'محفوظاتي (أوفلاين)', Icons.star, () => const SavedPage()],
      ]],
      ['Travel help hub', 'عبارات، أمان، طوارئ، أماكن، خدمات', Icons.luggage, [
        ['Phrasebook', 'عبارات المواقف', Icons.chat_bubble_outline, () => const PhrasebookPage()],
        ['Stay Safe', 'سعر عادل وأمان', Icons.shield, () => const SafePage()],
        ['Emergency & medical', 'طوارئ وكارت طبي', Icons.local_hospital, () => const EmergencyPage()],
        ['Places & weather', 'أماكن وطقس', Icons.place, () => const PlacesPage()],
        ['Official services', 'خدمات رسمية', Icons.account_balance, () => const OfficialPage()],
      ]],
      ['Daily puzzle', 'لغز اليوم وكلمة اليوم', Icons.extension, [
        ['Daily puzzle', 'لغز اليوم وكلمة اليوم', Icons.extension, () => const PuzzlePage()],
      ]],
      ['Nilo chat', 'دردشة نيلو', Icons.forum, [
        ['Nilo chat', 'دردشة نيلو', Icons.forum, () => const ModeGate()],
      ]],
    ];
    Widget sub(String title, List items) => Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(title: Text(L(title)), backgroundColor: Colors.transparent, elevation: 0),
          body: Stack(children: [
            const Positioned.fill(child: NileBackground()),
            ListView(padding: const EdgeInsets.all(14), children: [
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NiloTile(
                    icon: (it as List)[2] as IconData, title: it[0] as String, sub: it[1] as String,
                    onTap: () => Navigator.of(context).push(niloRoute((it[3] as Widget Function())())),
                  ),
                ),
            ]),
          ]),
        );
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Tools • أدوات'), style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(children: [
        const Positioned.fill(child: NileBackground()),
        ListView(padding: const EdgeInsets.all(14), children: [
          for (final h in hubs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NiloTile(
                icon: h[2] as IconData, title: h[0] as String, sub: h[1] as String,
                onTap: () {
                  final items = h[3] as List;
                  if (items.length == 1) {
                    Navigator.of(context).push(niloRoute(((items[0] as List)[3] as Widget Function())()));
                  } else {
                    Navigator.of(context).push(niloRoute(sub(h[0] as String, items)));
                  }
                },
              ),
            ),
          const SizedBox(height: 10),
          Text(L('الترجمة الآلية ممكن تغلط، راجع أي حاجة مهمة. مجاني، من غير حساب ولا إعلانات.\nتطبيق مصري خالص • صُنع بواسطة Mohamed Mostafa'), textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, height: 1.5, color: Colors.white54)),
        ]),
      ]),
    );
  }
}

// ---------------- Translate ----------------
class TranslatePage extends StatefulWidget {
  const TranslatePage({super.key});
  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final ctl = TextEditingController();
  String from = 'auto', to = 'ar', tone = 'natural';
  TrResult? res;
  TrResult? back;
  bool busy = false, rec = false;
  final mic = Mic();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() { from = p.getString('tr_from') ?? 'auto'; to = p.getString('tr_to') ?? 'ar'; }));
  }

  Future<void> save() async { final p = await SharedPreferences.getInstance(); await p.setString('tr_from', from); await p.setString('tr_to', to); }

  Future<void> run(Future<TrResult> f) async {
    setState(() { busy = true; res = null; back = null; });
    final r = await f;
    if (mounted) setState(() { busy = false; res = r; });
  }

  Future<void> doText() async {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    await run(trText(t, from, to, tone));
  }

  Future<void> doMic() async {
    if (!rec) {
      final ok = await mic.start();
      if (!ok) { if (mounted) toast(context, 'محتاج إذن الميكروفون'); return; }
      setState(() => rec = true);
    } else {
      setState(() => rec = false);
      final b = await mic.stop();
      if (b == null || b.length < 2000) { if (mounted) toast(context, 'التسجيل قصير'); return; }
      await run(trAudio(b, 'audio/mp4', from, to, tone));
    }
  }

  Future<void> doFile() async {
    final f = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
    final path = f?.files.single.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    if (bytes.length > 2900000) { if (mounted) toast(context, 'الفويس طويل (أكتر من حوالي 3 ميجا). قصّه. الفويس الطويل التلقائي في نسخة الويب.'); return; }
    final n = path.toLowerCase();
    final mime = n.endsWith('.ogg') || n.endsWith('.opus') || n.endsWith('.oga') ? 'audio/ogg' : n.endsWith('.mp3') ? 'audio/mpeg' : n.endsWith('.wav') ? 'audio/wav' : 'audio/mp4';
    await run(trAudio(bytes, mime, from, to, tone));
  }

  Future<void> doBack() async {
    if (res == null || !res!.ok) return;
    final r = await trText(res!.translation, to, from == 'auto' ? (res!.lang.isEmpty ? 'en' : res!.lang) : from, tone);
    if (mounted) setState(() => back = r);
  }

  @override
  void dispose() { mic.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Translate • ترجمة')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Row(children: [
            Expanded(child: LangDrop(value: from, auto: true, onChanged: (v) { setState(() => from = v); save(); })),
            IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () { if (from != 'auto') { setState(() { final t = from; from = to; to = t; }); save(); } }),
            Expanded(child: LangDrop(value: to, onChanged: (v) { setState(() => to = v); save(); })),
          ]),
          DropdownButton<String>(
            value: tone, isExpanded: true,
            items: [for (final t in kTones) DropdownMenuItem(value: t[0], child: Text(Ui.rtl ? 'النبرة: ${t[1]}' : 'Tone: ${t[1]}'))],
            onChanged: (v) { if (v != null) setState(() => tone = v); },
          ),
          TextField(controller: ctl, minLines: 3, maxLines: 6, decoration: InputDecoration(border: OutlineInputBorder(), hintText: L('اكتب أو الصق هنا'))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: busy ? null : doText, child: Text(L('ترجم'))),
            OutlinedButton.icon(onPressed: busy ? null : () async { final d = await Clipboard.getData('text/plain'); if (d?.text != null) { ctl.text = d!.text!; doText(); } }, icon: Icon(Icons.paste), label: Text(L('الصق وترجم'))),
            OutlinedButton.icon(onPressed: busy ? null : doMic, icon: Icon(rec ? Icons.stop : Icons.mic, color: rec ? Colors.redAccent : null), label: Text(rec ? 'وقف وترجم' : 'سجّل صوت')),
            OutlinedButton.icon(onPressed: busy ? null : doFile, icon: Icon(Icons.upload_file), label: Text(L('ارفع فويس'))),
          ]),
          if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (res != null) ResultCard(r: res!, to: to),
          if (res != null && res!.ok) TextButton(onPressed: doBack, child: Text(L('ترجمة عكسية للتأكد'))),
          if (back != null) ResultCard(r: back!, to: from == 'auto' ? (res?.lang ?? 'en') : from),
          const SizedBox(height: 10),
          Text(L('فويس من تليجرام/واتساب: اضغط مشاركة على الفويس واختار Nilo (ترجمة نيلو).'), style: TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      );
}

// ---------------- Phrasebook (and Stay Safe phrases) ----------------
class PhrasesPage extends StatefulWidget {
  final String title, tag;
  final Map<String, List<String>> data;
  const PhrasesPage({super.key, required this.title, required this.data, required this.tag});
  @override
  State<PhrasesPage> createState() => _PhrasesPageState();
}

class _PhrasesPageState extends State<PhrasesPage> {
  String lang = 'en';
  late String sit;
  Map<String, dynamic> cache = {};
  final Set<String> loading = {};

  @override
  void initState() {
    super.initState();
    sit = widget.data.keys.first;
    SharedPreferences.getInstance().then((p) {
      final raw = p.getString('phc_${widget.tag}');
      setState(() { lang = p.getString('ph_lang') ?? 'en'; if (raw != null) cache = jsonDecode(raw) as Map<String, dynamic>; });
    });
  }

  Future<void> persist() async { final p = await SharedPreferences.getInstance(); await p.setString('phc_${widget.tag}', jsonEncode(cache)); await p.setString('ph_lang', lang); }

  Future<String?> get(String ph) async {
    final k = '$lang|$ph';
    if (cache[k] != null) return cache[k] as String;
    setState(() => loading.add(k));
    final r = await trText(ph, 'ar', lang);
    if (mounted) setState(() => loading.remove(k));
    if (!r.ok) { if (mounted) toast(context, r.error); return null; }
    cache[k] = r.translation;
    await persist();
    if (mounted) setState(() {});
    return r.translation;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.data[sit]!;
    return Scaffold(
      appBar: AppBar(title: Text(L(widget.title)), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text(L('الجمل بالعربي المصري (بتتنطق)، ومعناها بلغتك. دوس الجملة لمعناها. بتتحفظ للاستخدام من غير نت.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
        LangDrop(value: lang, onChanged: (v) { setState(() => lang = v); persist(); }),
        DropdownButton<String>(value: sit, isExpanded: true, items: [for (final s in widget.data.keys) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) { if (v != null) setState(() => sit = v); }),
        for (final ph in list)
          Card(
            color: const Color(0xFF12304D),
            child: ListTile(
              title: Text(ph),
              subtitle: Text(loading.contains('$lang|$ph') ? '...' : (cache['$lang|$ph'] as String? ?? 'دوس للمعنى'), textDirection: TextDirection.ltr),
              onTap: () => get(ph),
              trailing: IconButton(icon: const Icon(Icons.volume_up), onPressed: () async { if (!await speak(ph, 'ar') && context.mounted) toast(context, 'الجهاز مفيهوش صوت عربي'); }),
            ),
          ),
        Text(L('الجمل كتبتها أنا ومترجعتش مع متحدث مصري. الترجمة آلية. راجع الطوارئ والحساسية.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}

// ---------------- Stay Safe ----------------
class SafePage extends StatefulWidget {
  const SafePage({super.key});
  @override
  State<SafePage> createState() => _SafePageState();
}

class _SafePageState extends State<SafePage> {
  final svc = TextEditingController(), price = TextEditingController();
  String cur = 'جنيه مصري', who = 'للشخص الواحد', way = 'رايح وجاي';
  String shown = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Stay Safe • أمان')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Text(L('ورقة اتفاق السعر • Price card'), style: TextStyle(fontWeight: FontWeight.bold)),
          Text(L('Fill it and show the screen to the driver before you ride.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
          TextField(controller: svc, decoration: InputDecoration(hintText: L('Service (camel, taxi, boat...)'))),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: L('Price'))),
          Row(children: [
            Expanded(child: DropdownButton<String>(value: cur, isExpanded: true, items: ['جنيه مصري', 'دولار', 'يورو', 'جنيه إسترليني'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => cur = v!))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButton<String>(value: who, isExpanded: true, items: ['للشخص الواحد', 'للمجموعة كلها'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => who = v!))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButton<String>(value: way, isExpanded: true, items: ['رايح وجاي', 'رايح بس'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => way = v!))),
          ]),
          FilledButton(onPressed: () { if (price.text.trim().isEmpty) { toast(context, 'Enter a price'); return; } setState(() => shown = 'الخدمة: ${svc.text.trim().isEmpty ? '-' : svc.text.trim()}\nالسعر: ${price.text.trim()} $cur $who\n$way\nمفيش أي مبلغ زيادة بعد كده.\nاتفقنا؟'); }, child: Text(L('Show to driver • اعرض'))),
          if (shown.isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: kGreen), borderRadius: BorderRadius.circular(8)), child: Text(shown, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, height: 1.8))),
          const Divider(height: 28),
          Text(L('Taxi and Uber checklist'), style: TextStyle(fontWeight: FontWeight.bold)),
          Text(L('• Many taxis lack working meters: agree the fare first or use a ride app (source: atlas-guide.com, read 26 Nov 2026).'), textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.atlas-guide.com/resources/scams/egypt'), child: Text(L('atlas-guide.com'))),
          Text(L('• Check the plate and car in the app before you get in (my general advice, not an official rule).'), textDirection: TextDirection.ltr),
          Text(L('• Pay the amount shown in the app. Complaints about drivers asking for more: TripAdvisor forum, Dec 2024.'), textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.tripadvisor.com/ShowTopic-g294201-i9404-k14962719-Be_careful_with_Uber_in_Cairo_Egypt-Cairo_Cairo_Governorate.html'), child: Text(L('TripAdvisor forum'))),
          Text(L('• Report crime to the tourist police: 126 (UK FCDO).'), textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.gov.uk/foreign-travel-advice/egypt/safety-and-security'), child: Text(L('gov.uk safety advice'))),
          const Divider(height: 28),
          OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhrasebookPage(title: L('Polite no and fair price • رفض مهذب وسعر عادل'), data: kSafe))), child: Text(L('جمل الأمان (رفض مهذب، تاكسي، سيدات، أكل)'))),
        ]),
      );
}

// ---------------- Emergency + medical card ----------------
class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});
  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final c = {for (final k in ['blood', 'allergy', 'cond', 'emerg']) k: TextEditingController()};
  String show = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) { for (final k in c.keys) { c[k]!.text = p.getString('med_$k') ?? ''; } setState(() {}); });
  }

  Future<void> save() async { final p = await SharedPreferences.getInstance(); for (final k in c.keys) { await p.setString('med_$k', c[k]!.text); } }

  Future<void> doShow() async {
    await save();
    final txt = 'Blood type: ${c['blood']!.text}\nAllergies: ${c['allergy']!.text}\nConditions and medicines: ${c['cond']!.text}\nEmergency contact: ${c['emerg']!.text}';
    setState(() { busy = true; show = ''; });
    final r = await trText(txt, 'auto', 'fus', 'formal');
    if (mounted) setState(() { busy = false; show = r.ok ? r.translation : '$txt\n\n(Translation unavailable. Show this text.)'; });
  }

  Widget num(String n, String label) => ListTile(title: Text(L(label)), trailing: TextButton(onPressed: () => openUrl('tel:$n'), child: Text(n, style: TextStyle(fontSize: 24))));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Emergency • طوارئ')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          num('123', 'Ambulance • إسعاف'), num('122', 'Police • شرطة'), num('126', 'Tourist police • شرطة السياحة'), num('180', 'Fire • مطافي'),
          Text(L('Checked 26 Nov 2026 against UK FCDO and the US Embassy in Cairo.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
          Row(children: [TextButton(onPressed: () => openUrl('https://www.gov.uk/foreign-travel-advice/egypt/getting-help'), child: Text(L('gov.uk'))), TextButton(onPressed: () => openUrl('https://eg.usembassy.gov/services/emergency-contact-information-for-u-s-citizens/'), child: Text(L('eg.usembassy.gov')))]),
          const Divider(height: 24),
          Text(L('Medical card • كارت طبي'), style: TextStyle(fontWeight: FontWeight.bold)),
          Text(L('Saved on this phone only.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
          TextField(controller: c['blood'], decoration: InputDecoration(labelText: L('Blood type'))),
          TextField(controller: c['allergy'], decoration: InputDecoration(labelText: L('Allergies (drugs, food)'))),
          TextField(controller: c['cond'], decoration: InputDecoration(labelText: L('Conditions and medicines'))),
          TextField(controller: c['emerg'], decoration: InputDecoration(labelText: L('Emergency contact'))),
          const SizedBox(height: 8),
          Row(children: [FilledButton(onPressed: () async { await save(); if (context.mounted) toast(context, 'Saved'); }, child: Text(L('Save'))), SizedBox(width: 8), OutlinedButton(onPressed: busy ? null : doShow, child: Text(L('Show to doctor (Arabic)')))]),
          if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (show.isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: kGreen), borderRadius: BorderRadius.circular(8)), child: Text(show, style: const TextStyle(fontSize: 22, height: 1.8))),
          Text(L('Automatic translation can be wrong. Do not rely on it alone for medical decisions.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}

// ---------------- Camera ----------------
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String to = 'ar';
  TrResult? res;
  bool busy = false;
  Future<void> go(ImageSource s) async {
    final x = await ImagePicker().pickImage(source: s, maxWidth: 1400, imageQuality: 80);
    if (x == null) return;
    setState(() { busy = true; res = null; });
    final bytes = await x.readAsBytes();
    final r = await trImage(bytes, 'image/jpeg', to);
    if (mounted) setState(() { busy = false; res = r; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Camera • كاميرا')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Text(L('Translate to:')),
          LangDrop(value: to, onChanged: (v) => setState(() => to = v)),
          Row(children: [FilledButton.icon(onPressed: busy ? null : () => go(ImageSource.camera), icon: Icon(Icons.photo_camera), label: Text(L('صوّر'))), SizedBox(width: 8), OutlinedButton.icon(onPressed: busy ? null : () => go(ImageSource.gallery), icon: Icon(Icons.photo), label: Text(L('من المعرض')))]),
          if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (res != null) ResultCard(r: res!, to: to),
          Text(L('الصورة بتتصغر وبتتبعت للترجمة ومش بتتحفظ. الخط اليدوي والصور الغامقة ممكن تفشل.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}

// ---------------- Face to face ----------------
class FacePage extends StatefulWidget {
  const FacePage({super.key});
  @override
  State<FacePage> createState() => _FacePageState();
}

class _FacePageState extends State<FacePage> {
  String them = 'en', me = 'ar';
  String topText = '', botText = '';
  final mic = Mic();
  int recSide = 0; // 0 none, 1 top (them), 2 bottom (me)
  bool busy = false;

  Future<void> press(int side) async {
    if (busy) return;
    if (recSide == 0) {
      if (!await mic.start()) { if (mounted) toast(context, 'محتاج إذن الميكروفون'); return; }
      setState(() => recSide = side);
    } else if (recSide == side) {
      setState(() { recSide = 0; busy = true; });
      final b = await mic.stop();
      if (b == null || b.length < 2000) { setState(() => busy = false); return; }
      // top = the other person speaks their language, we show the Arabic meaning at the bottom (for me)
      final fromL = side == 1 ? them : me, toL = side == 1 ? me : them;
      final r = await trAudio(b, 'audio/mp4', fromL, toL);
      if (!mounted) return;
      setState(() {
        busy = false;
        final t = r.ok ? r.translation : '⚠ ${r.error.isEmpty ? 'مسمعتش كلام واضح' : r.error}';
        if (side == 1) { botText = t; } else { topText = t; }
      });
      if (r.ok && side == 2) speak(r.translation, toL);
    }
  }

  @override
  void dispose() { mic.dispose(); super.dispose(); }

  Widget half(int side, String text, String lang, ValueChanged<String> onLang) => Expanded(
        child: Container(
          width: double.infinity,
          color: side == 1 ? const Color(0xFF1B2A3A) : const Color(0xFF12304D),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            SizedBox(width: 200, child: LangDrop(value: lang, onChanged: onLang)),
            Expanded(child: Center(child: SingleChildScrollView(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26))))),
            FilledButton.icon(
              onPressed: busy ? null : () => press(side),
              icon: Icon(recSide == side ? Icons.stop : Icons.mic),
              label: Text(recSide == side ? 'وقف' : (side == 1 ? 'Tap and speak' : 'دوس وتكلم')),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Face to face • وجهاً لوجه')), backgroundColor: kBg),
        body: Column(children: [
          Expanded(child: Transform.rotate(angle: math.pi, child: Column(children: [half(1, topText, them, (v) => setState(() => them = v))]))),
          const Divider(height: 1),
          Expanded(child: Column(children: [half(2, botText, me, (v) => setState(() => me = v))])),
        ]),
      );
}

// ---------------- Places ----------------
class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  int di = 0;
  String weather = '', guide = '', guideUrl = '', stamp = '';
  List<Map<String, dynamic>> pages = [];
  String osm = '', osmErr = '';
  bool osmBusy = false;
  String pagesErr = '';
  String guideLang = 'en', guideTr = '';
  bool guideBusy = false;

  @override
  void initState() { super.initState(); load(); }

  String now() { final d = DateTime.now(); return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }

  Future<dynamic> getJ(String u) async {
    final r = await http.get(Uri.parse(u), headers: {'User-Agent': 'NiloApp/1.0 (tourist helper)'}).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception(r.statusCode);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<void> load() async {
    final d = kDest[di];
    final n = d[0] as String, la = d[1] as double, lo = d[2] as double;
    setState(() { weather = ''; guide = ''; pages = []; osm = ''; osmErr = ''; pagesErr = ''; stamp = now(); });
    try {
      final w = await getJ('https://api.open-meteo.com/v1/forecast?latitude=$la&longitude=$lo&current=temperature_2m&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=3');
      final mx = (w['daily']['temperature_2m_max'] as List), mn = (w['daily']['temperature_2m_min'] as List);
      if (mounted) setState(() => weather = 'Now ${w['current']['temperature_2m']}°C. Next 3 days max/min: ${[for (var i = 0; i < mx.length; i++) '${mx[i]}/${mn[i]}'].join(' · ')} °C');
    } catch (_) { if (mounted) setState(() => weather = 'Weather not available'); }
    try {
      final g = await getJ('https://en.wikivoyage.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&redirects=1&titles=${Uri.encodeComponent(n)}&format=json');
      final p = (g['query']['pages'] as Map).values.first as Map;
      final e = (p['extract'] ?? '').toString();
      if (mounted) setState(() { guide = e.length > 900 ? '${e.substring(0, 900)}...' : e; guideUrl = 'https://en.wikivoyage.org/wiki/${n.replaceAll(' ', '_')}'; });
    } catch (_) {}
    try {
      final j = await getJ('https://en.wikipedia.org/w/api.php?action=query&generator=geosearch&ggscoord=$la%7C$lo&ggsradius=8000&ggslimit=15&prop=extracts&exintro=1&explaintext=1&exchars=170&format=json');
      final ps = ((j['query']['pages'] as Map).values.toList().cast<Map>()..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int)));
      if (mounted) setState(() => pages = ps.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) { if (mounted) setState(() => pagesErr = 'Could not load: $e'); }
  }

  Future<void> readGuide() async {
    if (guideLang == 'en') {
      if (!await speak(guide, 'en') && mounted) toast(context, 'الجهاز مفيهوش صوت للغة دي');
      return;
    }
    setState(() => guideBusy = true);
    final r = await trText(guide, 'en', guideLang);
    if (!mounted) return;
    setState(() { guideBusy = false; if (r.ok) guideTr = r.translation; });
    if (r.ok) {
      if (!await speak(r.translation, guideLang) && mounted) toast(context, 'الجهاز مفيهوش صوت للغة دي');
    } else {
      toast(context, r.error.isEmpty ? 'الترجمة فشلت' : r.error);
    }
  }

  Future<void> loadOsm(String tag, String val) async {
    final d = kDest[di];
    setState(() { osmBusy = true; osm = ''; osmErr = ''; });
    final q = '[out:json][timeout:20];nwr(around:2000,${d[1]},${d[2]})["$tag"="$val"];out center 15;';
    try {
      final r = await http.post(Uri.parse('https://overpass-api.de/api/interpreter'), headers: {'User-Agent': 'NiloApp/1.0 (tourist helper)', 'Content-Type': 'application/x-www-form-urlencoded'}, body: 'data=${Uri.encodeComponent(q)}').timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception(r.statusCode);
      final els = (jsonDecode(utf8.decode(r.bodyBytes))['elements'] as List);
      final lines = <String>[];
      for (final e in els) {
        final t = (e['tags'] ?? {}) as Map;
        lines.add((t['name:en'] ?? t['name'] ?? '(no name)').toString());
      }
      if (mounted) setState(() => osm = lines.isEmpty ? 'None found within 2 km in OpenStreetMap (the map may be incomplete).' : lines.join('\n'));
    } catch (e) { if (mounted) setState(() => osmErr = 'OpenStreetMap server busy or no internet. Try again. ($e)'); }
    if (mounted) setState(() => osmBusy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Places • أماكن')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Text(L('Loaded live from open sources each time: Wikivoyage, Wikipedia, OpenStreetMap, Open-Meteo. Nothing here is written or checked by Nilo.'), style: TextStyle(fontSize: 12, color: Colors.white60)),
          DropdownButton<int>(value: di, isExpanded: true, items: [for (var i = 0; i < kDest.length; i++) DropdownMenuItem(value: i, child: Text(kDest[i][0] as String))], onChanged: (v) { if (v != null) { di = v; load(); } }),
          Text(Ui.rtl ? 'اتحمّل: $stamp' : 'Loaded: $stamp', style: TextStyle(fontSize: 11, color: Colors.white38)),
          if (weather.isNotEmpty) Card(color: Color(0xFF12304D), child: Padding(padding: EdgeInsets.all(12), child: Text(Ui.rtl ? 'الطقس\n$weather\nالمصدر: Open-Meteo' : 'Weather\n$weather\nSource: Open-Meteo'))),
          if (guide.isNotEmpty) Card(color: Color(0xFF12304D), child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(Ui.rtl ? 'دليل سفر ${kDest[di][0]}' : '${kDest[di][0]} travel guide', style: TextStyle(fontWeight: FontWeight.bold)), Text(guide, textDirection: TextDirection.ltr), Row(children: [Expanded(child: DropdownButton<String>(isExpanded: true, value: guideLang, items: [for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(kNames[i], overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() { guideLang = v ?? 'en'; guideTr = ''; }))), IconButton(icon: guideBusy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.volume_up), onPressed: guideBusy ? null : readGuide)]), if (guideTr.isNotEmpty) Text(guideTr), TextButton(onPressed: () => openUrl(guideUrl), child: Text(L('Wikivoyage (CC BY-SA), community-written, may be out of date')))]))),
          Text(L('Places nearby (Wikipedia)'), style: TextStyle(fontWeight: FontWeight.bold)),
          if (pagesErr.isNotEmpty) Text(L(pagesErr)),
          for (final p in pages) ListTile(title: Text((p['title'] ?? '').toString(), textDirection: TextDirection.ltr), subtitle: Text((p['extract'] ?? '').toString(), textDirection: TextDirection.ltr), onTap: () => openUrl('https://en.wikipedia.org/?curid=${p['pageid']}')),
          Text(L('Wikipedia articles within 8 km, nearest first. Not a curated list: can include governorates and non-tourist pages. Hours and prices are not in this source.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
          const Divider(height: 24),
          Text(L('Services within 2 km (OpenStreetMap)'), style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 6, children: [
            for (final t in [['Pharmacy', 'amenity', 'pharmacy'], ['Hospital', 'amenity', 'hospital'], ['ATM', 'amenity', 'atm'], ['Mosque', 'amenity', 'place_of_worship'], ['Restaurant', 'amenity', 'restaurant'], ['Toilets', 'amenity', 'toilets']])
              OutlinedButton(onPressed: osmBusy ? null : () => loadOsm(t[1], t[2]), child: Text(t[0])),
          ]),
          if (osmBusy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (osm.isNotEmpty) Text(L(osm), textDirection: TextDirection.ltr),
          if (osmErr.isNotEmpty) Text(L(osmErr)),
          Text(L('© OpenStreetMap contributors. Volunteer data: may be missing or outdated.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}

class CapturePage extends StatelessWidget {
  const CapturePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('ترجمة صوت التطبيقات')), backgroundColor: kBg),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L('بتسجل الصوت اللي بيطلع من موبايلك (فيديو أو فويس) وتترجمه. أندرويد 10 أو أحدث. أندرويد بيطلب إذنك كل مرة.\nبعض التطبيقات بتمنع التسجيل والمكالمات مش بتتسجل. جرّب الأول، ولو طلع فاضي استخدم المايك أو مشاركة الملف.'), style: TextStyle(height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
                icon: const Icon(Icons.fiber_manual_record),
                label: Text(L('ابدأ التسجيل')),
                onPressed: () async {
                  try {
                    await const MethodChannel('nilo/native').invokeMethod('capture');
                  } catch (_) {
                    toast(context, 'مش متاح على الجهاز ده');
                  }
                },
              ),
            ),
          ]),
        ),
      );
}

class FloatPage extends StatelessWidget {
  const FloatPage({super.key});
  Future<void> _call(BuildContext c, String m) async {
    try {
      await const MethodChannel('nilo/native').invokeMethod(m);
    } catch (_) {
      toast(c, 'مش متاح على الجهاز ده');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('الزر العايم • Floating button')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text(L('الزر ده بيستخدم خدمة "إمكانية الوصول" عشان يقرا النص اللي على الشاشة ويترجمه. التفعيل بيحتاج خطوات من إعدادات أندرويد، ومتجرّبش لسه على أجهزة كتير.'), style: TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          Text(L('1. اضغط "افتح معلومات التطبيق" تحت.\n2. اضغط النقط التلاتة فوق على اليمين، ثم "السماح بالإعدادات المقيّدة" (Allow restricted settings). لو الاختيار مش ظاهر، افتح إعدادات إمكانية الوصول وجرب تفعّل نيلو مرة الأول، وبعدين ارجع هنا.\n3. اضغط "افتح إعدادات إمكانية الوصول"، اختار نيلو وفعّله.'), style: TextStyle(height: 1.7)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(L('Android blocks accessibility for apps installed outside Google Play ("Restricted setting"). Open App info, tap the three-dot menu, choose "Allow restricted settings", then enable Nilo in Accessibility. The exact wording varies by phone brand and Android version.'), style: TextStyle(color: Colors.white70, height: 1.5)),
          ),
          const SizedBox(height: 18),
          SizedBox(height: 48, child: ElevatedButton(onPressed: () => _call(context, 'appinfo'), child: Text(L('افتح معلومات التطبيق')))),
          const SizedBox(height: 10),
          SizedBox(height: 48, child: ElevatedButton(onPressed: () => _call(context, 'a11y'), child: Text(L('افتح إعدادات إمكانية الوصول')))),
        ]),
      );
}


/// Prominent card: live translation bubble over other apps.
class LiveCard extends StatelessWidget {
  const LiveCard({super.key});
  Future<void> _call(BuildContext c, String m) async {
    try { await const MethodChannel('nilo/native').invokeMethod(m); } catch (e) { if (c.mounted) toast(c, 'Could not open: $e'); }
  }
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF12304D), border: Border.all(color: kGreen), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.bubble_chart, color: kGreen), SizedBox(width: 8), Text(L('ترجمة فورية • Instant translation'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 6),
          Text(L('A floating bubble that translates what is on your screen, over any app. Turn it on once in Accessibility. If Android says the setting is restricted, use the steps page first.'), style: TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: () => _call(context, 'a11y'), child: Text(L('فعّل الآن • Turn on'))),
            OutlinedButton(onPressed: () => Navigator.of(context).push(niloRoute(FloatPage())), child: Text(L('الخطوات • Steps'))),
          ]),
        ]),
      );
}
