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
import 'net.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
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
          if (auto) const DropdownMenuItem(value: 'auto', child: Text('تلقائي Auto')),
          for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(kNames[i])),
        ],
        onChanged: (v) { if (v != null) onChanged(v); },
      );
}

class ResultCard extends StatelessWidget {
  final TrResult r;
  final String to;
  const ResultCard({super.key, required this.r, required this.to});
  @override
  Widget build(BuildContext context) {
    if (r.translation.isEmpty) {
      return Padding(padding: const EdgeInsets.all(8), child: Text('⚠ ${r.error.isEmpty ? 'مفيش نتيجة' : r.error}', style: const TextStyle(color: Colors.orangeAccent)));
    }
    return Card(
      color: const Color(0xFF1F2328),
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
          ]),
          const Text('ترجمة آلية: ممكن تغلط', style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
    );
  }
}

// ---------------- Home ----------------
class TouristHome extends StatelessWidget {
  const TouristHome({super.key});
  @override
  Widget build(BuildContext context) {
    final items = <List<Object>>[
      ['Translate', 'ترجمة 52 لغة (نص وفويس)', Icons.translate, () => const TranslatePage()],
      ['Face to face', 'وجهاً لوجه', Icons.people, () => const FacePage()],
      ['Camera', 'منيو ولافتات', Icons.photo_camera, () => const CameraPage()],
      ['Phrasebook', 'عبارات المواقف', Icons.chat_bubble_outline, () => const PhrasesPage(title: 'Phrasebook', data: kPhrases, tag: 'ph')],
      ['Stay Safe', 'سعر عادل وأمان', Icons.shield, () => const SafePage()],
      ['Places & weather', 'أماكن وطقس', Icons.place, () => const PlacesPage()],
      ['Emergency & medical', 'طوارئ وكارت طبي', Icons.local_hospital, () => const EmergencyPage()],
      ['Official services', 'خدمات رسمية', Icons.account_balance, () => const OfficialPage()],
      ['Chat & sales', 'دردشة نيلو', Icons.forum, () => const ModeGate()],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Nilo • نيلو'), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('Your pocket companion in Egypt\nرفيقك في مصر', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.25,
          children: [
            for (var n = 0; n < items.length; n++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + n * 70),
                curve: Curves.easeOutCubic,
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(niloRoute((items[n][3] as Widget Function())())),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF1F2429), border: Border.all(color: kGreen.withOpacity(0.5)), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(items[n][2] as IconData, color: kGreen),
                      const SizedBox(height: 6),
                      Text(items[n][0] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(items[n][1] as String, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('الترجمة الآلية ممكن تغلط، راجع أي حاجة مهمة. مجاني، من غير حساب ولا إعلانات.\nتطبيق مصري خالص • صُنع بواسطة Mohamed Mostafa', style: TextStyle(fontSize: 12, color: Colors.white54)),
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
        appBar: AppBar(title: const Text('Translate • ترجمة'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Row(children: [
            Expanded(child: LangDrop(value: from, auto: true, onChanged: (v) { setState(() => from = v); save(); })),
            IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () { if (from != 'auto') { setState(() { final t = from; from = to; to = t; }); save(); } }),
            Expanded(child: LangDrop(value: to, onChanged: (v) { setState(() => to = v); save(); })),
          ]),
          DropdownButton<String>(
            value: tone, isExpanded: true,
            items: [for (final t in kTones) DropdownMenuItem(value: t[0], child: Text('النبرة: ${t[1]}'))],
            onChanged: (v) { if (v != null) setState(() => tone = v); },
          ),
          TextField(controller: ctl, minLines: 3, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب أو الصق هنا')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: busy ? null : doText, child: const Text('ترجم')),
            OutlinedButton.icon(onPressed: busy ? null : () async { final d = await Clipboard.getData('text/plain'); if (d?.text != null) { ctl.text = d!.text!; doText(); } }, icon: const Icon(Icons.paste), label: const Text('الصق وترجم')),
            OutlinedButton.icon(onPressed: busy ? null : doMic, icon: Icon(rec ? Icons.stop : Icons.mic, color: rec ? Colors.redAccent : null), label: Text(rec ? 'وقف وترجم' : 'سجّل صوت')),
            OutlinedButton.icon(onPressed: busy ? null : doFile, icon: const Icon(Icons.upload_file), label: const Text('ارفع فويس')),
          ]),
          if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (res != null) ResultCard(r: res!, to: to),
          if (res != null && res!.ok) TextButton(onPressed: doBack, child: const Text('ترجمة عكسية للتأكد')),
          if (back != null) ResultCard(r: back!, to: from == 'auto' ? (res?.lang ?? 'en') : from),
          const SizedBox(height: 10),
          const Text('فويس من تليجرام/واتساب: اضغط مشاركة على الفويس واختار Nilo (ترجمة نيلو).', style: TextStyle(fontSize: 12, color: Colors.white54)),
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
      appBar: AppBar(title: Text(widget.title), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('الجمل بالعربي المصري (بتتنطق)، ومعناها بلغتك. دوس الجملة لمعناها. بتتحفظ للاستخدام من غير نت.', style: TextStyle(fontSize: 12, color: Colors.white60)),
        LangDrop(value: lang, onChanged: (v) { setState(() => lang = v); persist(); }),
        DropdownButton<String>(value: sit, isExpanded: true, items: [for (final s in widget.data.keys) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) { if (v != null) setState(() => sit = v); }),
        for (final ph in list)
          Card(
            color: const Color(0xFF1F2328),
            child: ListTile(
              title: Text(ph),
              subtitle: Text(loading.contains('$lang|$ph') ? '...' : (cache['$lang|$ph'] as String? ?? 'دوس للمعنى'), textDirection: TextDirection.ltr),
              onTap: () => get(ph),
              trailing: IconButton(icon: const Icon(Icons.volume_up), onPressed: () async { if (!await speak(ph, 'ar') && context.mounted) toast(context, 'الجهاز مفيهوش صوت عربي'); }),
            ),
          ),
        const Text('الجمل كتبتها أنا ومترجعتش مع متحدث مصري. الترجمة آلية. راجع الطوارئ والحساسية.', style: TextStyle(fontSize: 11, color: Colors.white38)),
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
        appBar: AppBar(title: const Text('Stay Safe • أمان'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('ورقة اتفاق السعر • Price card', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Fill it and show the screen to the driver before you ride.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          TextField(controller: svc, decoration: const InputDecoration(hintText: 'Service (camel, taxi, boat...)')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Price')),
          Row(children: [
            Expanded(child: DropdownButton<String>(value: cur, isExpanded: true, items: ['جنيه مصري', 'دولار', 'يورو', 'جنيه إسترليني'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => cur = v!))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButton<String>(value: who, isExpanded: true, items: ['للشخص الواحد', 'للمجموعة كلها'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => who = v!))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButton<String>(value: way, isExpanded: true, items: ['رايح وجاي', 'رايح بس'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => way = v!))),
          ]),
          FilledButton(onPressed: () { if (price.text.trim().isEmpty) { toast(context, 'Enter a price'); return; } setState(() => shown = 'الخدمة: ${svc.text.trim().isEmpty ? '-' : svc.text.trim()}\nالسعر: ${price.text.trim()} $cur $who\n$way\nمفيش أي مبلغ زيادة بعد كده.\nاتفقنا؟'); }, child: const Text('Show to driver • اعرض')),
          if (shown.isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: kGreen), borderRadius: BorderRadius.circular(8)), child: Text(shown, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, height: 1.8))),
          const Divider(height: 28),
          const Text('Taxi and Uber checklist', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('• Many taxis lack working meters: agree the fare first or use a ride app (source: atlas-guide.com, read 26 Nov 2026).', textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.atlas-guide.com/resources/scams/egypt'), child: const Text('atlas-guide.com')),
          const Text('• Check the plate and car in the app before you get in (my general advice, not an official rule).', textDirection: TextDirection.ltr),
          const Text('• Pay the amount shown in the app. Complaints about drivers asking for more: TripAdvisor forum, Dec 2024.', textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.tripadvisor.com/ShowTopic-g294201-i9404-k14962719-Be_careful_with_Uber_in_Cairo_Egypt-Cairo_Cairo_Governorate.html'), child: const Text('TripAdvisor forum')),
          const Text('• Report crime to the tourist police: 126 (UK FCDO).', textDirection: TextDirection.ltr),
          TextButton(onPressed: () => openUrl('https://www.gov.uk/foreign-travel-advice/egypt/safety-and-security'), child: const Text('gov.uk safety advice')),
          const Divider(height: 28),
          OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhrasesPage(title: 'Polite no and fair price', data: kSafe, tag: 'sf'))), child: const Text('جمل الأمان (رفض مهذب، تاكسي، سيدات، أكل)')),
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

  Widget num(String n, String label) => ListTile(title: Text(label), trailing: TextButton(onPressed: () => openUrl('tel:$n'), child: Text(n, style: const TextStyle(fontSize: 24))));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Emergency • طوارئ'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          num('123', 'Ambulance • إسعاف'), num('122', 'Police • شرطة'), num('126', 'Tourist police • شرطة السياحة'), num('180', 'Fire • مطافي'),
          const Text('Checked 26 Nov 2026 against UK FCDO and the US Embassy in Cairo.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          Row(children: [TextButton(onPressed: () => openUrl('https://www.gov.uk/foreign-travel-advice/egypt/getting-help'), child: const Text('gov.uk')), TextButton(onPressed: () => openUrl('https://eg.usembassy.gov/services/emergency-contact-information-for-u-s-citizens/'), child: const Text('eg.usembassy.gov'))]),
          const Divider(height: 24),
          const Text('Medical card • كارت طبي', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Saved on this phone only.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          TextField(controller: c['blood'], decoration: const InputDecoration(labelText: 'Blood type')),
          TextField(controller: c['allergy'], decoration: const InputDecoration(labelText: 'Allergies (drugs, food)')),
          TextField(controller: c['cond'], decoration: const InputDecoration(labelText: 'Conditions and medicines')),
          TextField(controller: c['emerg'], decoration: const InputDecoration(labelText: 'Emergency contact')),
          const SizedBox(height: 8),
          Row(children: [FilledButton(onPressed: () async { await save(); if (context.mounted) toast(context, 'Saved'); }, child: const Text('Save')), const SizedBox(width: 8), OutlinedButton(onPressed: busy ? null : doShow, child: const Text('Show to doctor (Arabic)'))]),
          if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (show.isNotEmpty) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: kGreen), borderRadius: BorderRadius.circular(8)), child: Text(show, style: const TextStyle(fontSize: 22, height: 1.8))),
          const Text('Automatic translation can be wrong. Do not rely on it alone for medical decisions.', style: TextStyle(fontSize: 11, color: Colors.white38)),
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
        appBar: AppBar(title: const Text('Camera • كاميرا'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('Translate to:'),
          LangDrop(value: to, onChanged: (v) => setState(() => to = v)),
          Row(children: [FilledButton.icon(onPressed: busy ? null : () => go(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('صوّر')), const SizedBox(width: 8), OutlinedButton.icon(onPressed: busy ? null : () => go(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text('من المعرض'))]),
          if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (res != null) ResultCard(r: res!, to: to),
          const Text('الصورة بتتصغر وبتتبعت للترجمة ومش بتتحفظ. الخط اليدوي والصور الغامقة ممكن تفشل.', style: TextStyle(fontSize: 11, color: Colors.white38)),
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
          color: side == 1 ? const Color(0xFF1B2A3A) : const Color(0xFF1F2328),
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
        appBar: AppBar(title: const Text('Face to face • وجهاً لوجه'), backgroundColor: kBg),
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
        appBar: AppBar(title: const Text('Places • أماكن'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('Loaded live from open sources each time: Wikivoyage, Wikipedia, OpenStreetMap, Open-Meteo. Nothing here is written or checked by Nilo.', style: TextStyle(fontSize: 12, color: Colors.white60)),
          DropdownButton<int>(value: di, isExpanded: true, items: [for (var i = 0; i < kDest.length; i++) DropdownMenuItem(value: i, child: Text(kDest[i][0] as String))], onChanged: (v) { if (v != null) { di = v; load(); } }),
          Text('Loaded: $stamp', style: const TextStyle(fontSize: 11, color: Colors.white38)),
          if (weather.isNotEmpty) Card(color: const Color(0xFF1F2328), child: Padding(padding: const EdgeInsets.all(12), child: Text('Weather\n$weather\nSource: Open-Meteo'))),
          if (guide.isNotEmpty) Card(color: const Color(0xFF1F2328), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${kDest[di][0]} travel guide', style: const TextStyle(fontWeight: FontWeight.bold)), Text(guide, textDirection: TextDirection.ltr), TextButton(onPressed: () => openUrl(guideUrl), child: const Text('Wikivoyage (CC BY-SA), community-written, may be out of date'))]))),
          const Text('Places nearby (Wikipedia)', style: TextStyle(fontWeight: FontWeight.bold)),
          if (pagesErr.isNotEmpty) Text(pagesErr),
          for (final p in pages) ListTile(title: Text((p['title'] ?? '').toString(), textDirection: TextDirection.ltr), subtitle: Text((p['extract'] ?? '').toString(), textDirection: TextDirection.ltr), onTap: () => openUrl('https://en.wikipedia.org/?curid=${p['pageid']}')),
          const Text('Wikipedia articles within 8 km, nearest first. Not a curated list: can include governorates and non-tourist pages. Hours and prices are not in this source.', style: TextStyle(fontSize: 11, color: Colors.white38)),
          const Divider(height: 24),
          const Text('Services within 2 km (OpenStreetMap)', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(spacing: 6, children: [
            for (final t in [['Pharmacy', 'amenity', 'pharmacy'], ['Hospital', 'amenity', 'hospital'], ['ATM', 'amenity', 'atm'], ['Mosque', 'amenity', 'place_of_worship'], ['Restaurant', 'amenity', 'restaurant'], ['Toilets', 'amenity', 'toilets']])
              OutlinedButton(onPressed: osmBusy ? null : () => loadOsm(t[1], t[2]), child: Text(t[0])),
          ]),
          if (osmBusy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (osm.isNotEmpty) Text(osm, textDirection: TextDirection.ltr),
          if (osmErr.isNotEmpty) Text(osmErr),
          const Text('© OpenStreetMap contributors. Volunteer data: may be missing or outdated.', style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}
