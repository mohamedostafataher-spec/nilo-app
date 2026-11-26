// Nilo World: passport (stamps, XP, streak), home country, daily word/puzzle, chapters, papyrus trip animation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' show PlatformDispatcher;
import 'main.dart';
import 'settings.dart';
import 'journey.dart';
import 'screens.dart' show toast, ToolsPage;

/// code, English name, Arabic name, flag, lat, lon, symbol emoji, symbol name, hello, thanks
const List<List<Object>> kWorld = [
  ['EG', 'Egypt', 'مصر', '🇪🇬', 30.0, 31.2, '🔺', 'Pyramid', 'مرحبا', 'شكرا'],
  ['JP', 'Japan', 'اليابان', '🇯🇵', 35.7, 139.7, '🪁', 'Kite', 'こんにちは', 'ありがとう'],
  ['FR', 'France', 'فرنسا', '🇫🇷', 48.9, 2.35, '✒️', 'Quill pen', 'Bonjour', 'Merci'],
  ['CA', 'Canada', 'كندا', '🇨🇦', 45.4, -75.7, '🍁', 'Maple leaf', 'Hello', 'Thank you'],
  ['RU', 'Russia', 'روسيا', '🇷🇺', 55.75, 37.6, '🪆', 'Matryoshka doll', 'Привет', 'Спасибо'],
  ['UA', 'Ukraine', 'أوكرانيا', '🇺🇦', 50.45, 30.5, '🌻', 'Sunflower', 'Привіт', 'Дякую'],
  ['US', 'United States', 'أمريكا', '🇺🇸', 38.9, -77.0, '🗽', 'Statue of Liberty', 'Hello', 'Thank you'],
  ['GB', 'United Kingdom', 'بريطانيا', '🇬🇧', 51.5, -0.12, '🕰️', 'Clock tower', 'Hello', 'Thank you'],
  ['DE', 'Germany', 'ألمانيا', '🇩🇪', 52.5, 13.4, '🥨', 'Pretzel', 'Hallo', 'Danke'],
  ['IT', 'Italy', 'إيطاليا', '🇮🇹', 41.9, 12.5, '🏛️', 'Colosseum', 'Ciao', 'Grazie'],
  ['ES', 'Spain', 'إسبانيا', '🇪🇸', 40.4, -3.7, '💃', 'Flamenco dancer', 'Hola', 'Gracias'],
  ['TR', 'Turkey', 'تركيا', '🇹🇷', 39.9, 32.9, '🎈', 'Hot air balloon', 'Merhaba', 'Teşekkürler'],
  ['SA', 'Saudi Arabia', 'السعودية', '🇸🇦', 24.7, 46.7, '🌴', 'Palm tree', 'مرحبا', 'شكرا'],
  ['IN', 'India', 'الهند', '🇮🇳', 28.6, 77.2, '🪔', 'Diya lamp', 'नमस्ते', 'धन्यवाद'],
  ['CN', 'China', 'الصين', '🇨🇳', 39.9, 116.4, '🐼', 'Panda', '你好', '谢谢'],
  ['BR', 'Brazil', 'البرازيل', '🇧🇷', -15.8, -47.9, '🦜', 'Parrot', 'Olá', 'Obrigado'],
  ['MX', 'Mexico', 'المكسيك', '🇲🇽', 19.4, -99.1, '🌵', 'Cactus', 'Hola', 'Gracias'],
  ['KR', 'South Korea', 'كوريا الجنوبية', '🇰🇷', 37.6, 127.0, '🏯', 'Palace', '안녕하세요', '감사합니다'],
  ['AU', 'Australia', 'أستراليا', '🇦🇺', -35.3, 149.1, '🦘', 'Kangaroo', 'Hello', 'Thank you'],
];

List<Object> countryOf(String code) => kWorld.firstWhere((c) => c[0] == code, orElse: () => kWorld[0]);

/// Original, neutral riddles. answers: accepted words (lowercase).
const List<List<Object>> kRiddles = [
  ['What has keys but cannot open a door?', 'عندها مفاتيح بس مبتفتحش باب. إيه هي؟', ['piano', 'keyboard', 'بيانو', 'كيبورد', 'اورج', 'أورج']],
  ['What gets wetter the more it dries?', 'إيه اللي بيتبل أكتر كل ما ينشف؟', ['towel', 'فوطة', 'منشفة', 'فوطه']],
  ['I travel the world but stay in the corner. What am I?', 'بلف الدنيا وانا ساكن في الركن. أنا مين؟', ['stamp', 'ختم', 'طابع']],
  ['What has rivers and roads but no water or cars?', 'فيها أنهار وطرق من غير مية ولا عربيات. إيه هي؟', ['map', 'خريطة', 'خريطه']],
  ['The more you take, the more you leave behind. What are they?', 'كل ما تاخد منها أكتر، بتسيب وراك أكتر. إيه هي؟', ['steps', 'footsteps', 'step', 'خطوات', 'خطوة']],
  ['What can you catch but never throw?', 'إيه اللي تقدر تمسكه بس مش تقدر ترميه؟', ['cold', 'a cold', 'برد', 'زكام']],
  ['What has hands but cannot clap?', 'عندها ايدين بس مبتصقفش. إيه هي؟', ['clock', 'watch', 'ساعة', 'ساعه']],
];

/// Prologue and scroll 1 of "The Lost Papyrus Routes". Original text, short.
const List<List<Object>> kChapters = [
  ['Prologue: The Archive', 'الفصل صفر: الأرشيف',
    'Long ago, beside the Nile, keepers sealed seven scrolls in a quiet archive. Each scroll held a way of listening: to a stranger, a song, a map, a meal. When the river changed course, the scrolls were carried away along old trade routes. Nobody remembers where they went. Tonight, a strip of papyrus washed up at your door. It is blank, except for one word: "Begin".',
    'من زمان، على ضفة النيل، حراس قفلوا سبع لفائف في أرشيف هادي. كل لفة فيها طريقة للاستماع: لغريب، لأغنية، لخريطة، لأكلة. لما النهر غيّر مجراه، اتحملت اللفايف على طرق التجارة القديمة ومحدش فاكر راحت فين. الليلة جت ورقة بردي على بابك. فاضية، غير كلمة واحدة: "ابدأ".',
    'What do you do with the blank papyrus?', ['Write a greeting', 'Keep it safe']],
  ['Scroll 1, Chapter 1: The Keeper of your home', 'اللفة 1، الفصل 1: حارس بلدك',
    'Your home country has a keeper. Keepers do not guard treasure, they guard habits: how people say hello, what they cook when it rains, which song everyone knows. Your keeper whispers: "The first scroll opens only when someone from another country answers you." You need a friend from far away.',
    'لكل بلد حارس. الحراس مش بيحرسوا كنز، بيحرسوا عادات: إزاي الناس بتسلم، بتطبخ إيه وقت المطر، أنهي أغنية الكل يعرفها. حارس بلدك بيهمس: "اللفة الأولى مبتتفتحش غير لما حد من بلد تانية يرد عليك". محتاج صاحب من بعيد.',
    'How will you find someone far away?', ['Send a papyrus into the world', 'Ask Nilo for a hint']],
  ['Scroll 1, Chapter 2: The first reply', 'اللفة 1، الفصل 2: أول رد',
    'A papyrus crosses oceans in seconds on the map, but real replies take a little longer. While you wait, the keeper teaches you one word from another land. Words are keys. Every word you learn turns one small lock inside the archive.',
    'البردية بتعدي المحيطات في ثواني على الخريطة، بس الرد الحقيقي بياخد وقت أطول شوية. وانت مستني، الحارس بيعلمك كلمة من بلد تانية. الكلمات مفاتيح. كل كلمة تتعلمها بتفتح قفل صغير جوه الأرشيف.',
    'Which word will you learn first?', ['Hello', 'Thank you']],
  ['Scroll 1, Chapter 3: The scroll opens', 'اللفة 1، الفصل 3: اللفة بتتفتح',
    'The first scroll unrolls. It is a map with no names, only small symbols: a pyramid, a kite, a maple leaf, a sunflower. Under it, one line: "Every place on this map is somebody\'s home. Visit them kindly." Scroll 2 waits in a country you have not met yet.',
    'اللفة الأولى اتفتحت. خريطة من غير أسماء، رموز صغيرة بس: هرم، طيارة ورق، ورقة قيقب، عباد شمس. تحتها سطر: "كل مكان على الخريطة دي بيت حد. زورهم بلطف". اللفة 2 مستنية في بلد لسه متعرفتش عليها.',
    'How will you carry this scroll forward?', ['Share it with a friend', 'Keep exploring alone']],
];

class Passport {
  static late SharedPreferences _p;
  static Future<void> init() async { _p = await SharedPreferences.getInstance(); }
  static String get country => _p.getString('w_country') ?? '';
  static set country(String v) => _p.setString('w_country', v);
  static int get xp => _p.getInt('w_xp') ?? 0;
  static int get streak => _p.getInt('w_streak') ?? 0;
  static String get nickname => _p.getString('w_nick') ?? '';
  static set nickname(String v) => _p.setString('w_nick', v);
  static bool flag(String k, [bool d = true]) => _p.getBool('f_$k') ?? d;
  static void setFlag(String k, bool v) => _p.setBool('f_$k', v);
  static List<String> get stamps => _p.getStringList('w_stamps') ?? [];
  static int get chapter => _p.getInt('w_chapter') ?? 0;
  static String _today() { final d = DateTime.now(); return '${d.year}-${d.month}-${d.day}'; }
  static int _dayNum() => DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
  static int get startDay => _p.getInt('w_start') ?? _dayNum();
  static void addXp(int n) => _p.setInt('w_xp', xp + n);
  static void addStamp(String s) { final l = stamps; if (!l.contains(s)) { l.add(s); _p.setStringList('w_stamps', l); addXp(20); } }
  /// Call when the app opens: updates the daily streak.
  static void touch() {
    if (_p.getInt('w_start') == null) _p.setInt('w_start', _dayNum());
    final last = _p.getString('w_last') ?? '';
    if (last == _today()) return;
    final y = DateTime.now().subtract(const Duration(days: 1));
    final yd = '${y.year}-${y.month}-${y.day}';
    _p.setInt('w_streak', last == yd ? streak + 1 : 1);
    _p.setString('w_last', _today());
    addXp(5);
  }
  /// Daily batch: 10 papyri to catch and 10 ink to send, renewed at 12:00 local time (checked when the app opens).
  static String _noonKey() { final d = DateTime.now().subtract(const Duration(hours: 12)); return '${d.year}-${d.month}-${d.day}'; }
  static void _refill() {
    if (_p.getString('w_noon') != _noonKey()) { _p.setString('w_noon', _noonKey()); _p.setInt('w_ink', 10); _p.setInt('w_catch', 10); }
  }
  static int get ink { _refill(); return _p.getInt('w_ink') ?? 10; }
  static int get catchesLeft { _refill(); return _p.getInt('w_catch') ?? 10; }
  static bool useInk() { if (ink <= 0) return false; _p.setInt('w_ink', ink - 1); return true; }
  static void addInk(int n) { _p.setInt('w_ink', ink + n); }
  static bool useCatch() { if (catchesLeft <= 0) return false; _p.setInt('w_catch', catchesLeft - 1); return true; }
  static bool get puzzleDone => _p.getString('w_puz') == _today();
  static void puzzleSolved() { _p.setString('w_puz', _today()); addXp(15); addInk(3); addStamp('puzzle-${_today()}'); }
  static int get papyri => _p.getInt('w_sent') ?? 0;
  static void papyrusSent() { _p.setInt('w_sent', papyri + 1); addXp(10); }
  /// Chapters open one per day, or faster with papyri sent.
  static int get unlocked => math.min(kChapters.length, 1 + math.max(_dayNum() - startDay, papyri));
  static void finishChapter(int i) { if (i >= chapter) { _p.setInt('w_chapter', i + 1); addStamp('chapter-$i'); addXp(25); } }
}

/// Detects the country on the device. Asks for approximate (coarse) location, turns it into a country code with Android's geocoder,
/// keeps ONLY the code and drops the coordinates. Falls back to the phone's region setting. Returns '' if nothing usable.
Future<String> detectCountry({required bool allowGps}) async {
  if (allowGps) {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)).timeout(const Duration(seconds: 15));
        final pm = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(const Duration(seconds: 10));
        final cc = pm.isNotEmpty ? (pm.first.isoCountryCode ?? '') : '';
        if (cc.isNotEmpty) return cc.toUpperCase();
      }
    } catch (_) {}
  }
  // Mobile network / SIM country first: it follows where the phone really is, unlike the language setting (en_US on many Egyptian phones).
  try {
    final r = await const MethodChannel('nilo/native').invokeMethod<String>('region');
    if (r != null && r.length == 2) return r.toUpperCase();
  } catch (_) {}
  return PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
}

class CountryPickerPage extends StatelessWidget {
  const CountryPickerPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choose your home country • اختار بلدك'), backgroundColor: kBg),
        body: ListView(children: [
          for (final c in kWorld)
            ListTile(
              leading: Text(c[3] as String, style: const TextStyle(fontSize: 28)),
              title: Text('${c[1]} • ${c[2]}'),
              subtitle: Text('Symbol: ${c[6]} ${c[7]}'),
              onTap: () { Passport.country = c[0] as String; Passport.addStamp('home-${c[0]}'); Navigator.pop(context, true); },
            ),
          const Padding(padding: EdgeInsets.all(16), child: Text('More countries are coming. Only your country code is saved, on this phone.', style: TextStyle(color: Colors.white54, fontSize: 12))),
        ]),
      );
}

/// Top card on the home screen: home world, streak, daily word, daily puzzle, chapter.
class WorldCard extends StatefulWidget {
  const WorldCard({super.key});
  @override
  State<WorldCard> createState() => _WorldCardState();
}

class _WorldCardState extends State<WorldCard> {
  Future<void> _detect() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Find your country'),
      content: const Text('Nilo can use your approximate location once to work out your country. Only the country code is saved, on this phone and in your profile. Your coordinates are not stored. The Android geocoder service turns the position into a country name, so the position is sent to it for that moment. Location can be faked, so this only reduces cheating. If you say no, Nilo uses your phone region setting instead.', style: TextStyle(height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, use phone region')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Allow once')),
      ],
    ));
    if (ok == null) return;
    final cc = await detectCountry(allowGps: ok);
    if (!mounted) return;
    if (kWorld.any((c) => c[0] == cc)) {
      Passport.country = cc; Passport.addStamp('home-$cc');
      toast(context, 'Detected: ${countryOf(cc)[3]} ${countryOf(cc)[1]}');
      setState(() {});
    } else {
      toast(context, cc.isEmpty ? 'Could not detect. Pick your country.' : 'Country $cc is not in Nilo yet. Pick the closest one.');
      await _pick();
    }
  }

  Future<void> _pick() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CountryPickerPage()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = Passport.country;
    if (code.isEmpty) {
      return _box(InkWell(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => FirstRunPage(next: const _Back()))); if (mounted) setState(() {}); }, child: const Padding(padding: EdgeInsets.all(16),
        child: Row(children: [Text('🌍', style: TextStyle(fontSize: 34)), SizedBox(width: 12), Expanded(child: Text('Nai is waiting. Begin your story\nناي مستنيك. ابدأ حكايتك', style: TextStyle(fontSize: 16, height: 1.4))), Icon(Icons.chevron_right)]))));
    }
    final c = countryOf(code);
    return _box(Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(c[3] as String, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 10),
        Expanded(child: Text('${c[1]} world • ${c[6]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        TextButton(onPressed: _pick, child: const Text('Change')),
      ]),
      Text('🔥 ${Passport.streak} day streak   ⭐ ${Passport.xp} XP   🛂 ${Passport.stamps.length} stamps   🖋 ${Passport.ink} ink', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.today, size: 18), label: const Text('Daily word'), onPressed: () => _word(c)),
        ActionChip(avatar: Icon(Passport.puzzleDone ? Icons.check_circle : Icons.extension, size: 18), label: Text(Passport.puzzleDone ? 'Puzzle done' : 'Daily puzzle'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PuzzlePage())); if (mounted) setState(() {}); }),
        ActionChip(avatar: const Icon(Icons.auto_stories, size: 18), label: Text('Story ${math.min(Passport.chapter + 1, kChapters.length)}/${kChapters.length}'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryPage())); if (mounted) setState(() {}); }),
        ActionChip(avatar: const Icon(Icons.badge, size: 18), label: const Text('Passport'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassportPage()))),
      ]),
    ])));
  }

  void _word(List<Object> home) {
    final other = kWorld[(Passport._dayNum() + 3) % kWorld.length];
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Word of the day'),
      content: Text('${other[3]} ${other[1]}\n\nHello: ${other[8]}\nThank you: ${other[9]}\n\nTip: say it to someone from there. Spelling is shown in the local script.', style: const TextStyle(height: 1.5)),
      actions: [TextButton(onPressed: () { Passport.addStamp('word-${other[0]}'); Navigator.pop(context); setState(() {}); }, child: const Text('Got it, +stamp'))],
    ));
  }

  Widget _box(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFF12304D), border: Border.all(color: kGreen.withOpacity(0.6)), borderRadius: BorderRadius.circular(16)),
        child: Material(color: Colors.transparent, child: child),
      );
}

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});
  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  final c = TextEditingController();
  String msg = '';
  List<Object> get r => kRiddles[Passport._dayNum() % kRiddles.length];
  void _check() {
    final a = c.text.trim().toLowerCase();
    final ok = (r[2] as List<String>).any((x) => a == x || (a.length > 2 && a.contains(x)));
    setState(() => msg = ok ? 'Correct! +15 XP, +3 ink and a stamp.' : 'Not yet. Try again.');
    if (ok && !Passport.puzzleDone) Passport.puzzleSolved();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daily puzzle • لغز اليوم'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text(r[0] as String, style: const TextStyle(fontSize: 20, height: 1.4)),
          const SizedBox(height: 8),
          Text(r[1] as String, style: const TextStyle(fontSize: 18, color: kGreen, height: 1.4)),
          const SizedBox(height: 16),
          if (Passport.puzzleDone) const Text('You solved today\'s puzzle. Come back tomorrow.', style: TextStyle(color: Colors.white70)) else ...[
            TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your answer (English or Arabic)')),
            const SizedBox(height: 10),
            FilledButton(onPressed: _check, child: const Text('Check')),
          ],
          const SizedBox(height: 10),
          Text(msg),
        ]),
      );
}

class StoryPage extends StatefulWidget {
  const StoryPage({super.key});
  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  static const gold = Color(0xFFE0B04A);
  @override
  Widget build(BuildContext context) {
    final un = Passport.unlocked;
    final done = Passport.chapter.clamp(0, kChapters.length);
    final cur = done < un ? done : -1;
    String en(int i) { final t = kChapters[i][0] as String; final k = t.indexOf(': '); return k < 0 ? t : t.substring(k + 2); }
    String ar(int i) { final t = kChapters[i][1] as String; final k = t.indexOf(': '); return k < 0 ? t : t.substring(k + 2); }
    Future<void> open(int i) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterPage(i: i))); if (mounted) setState(() {}); }
    return Scaffold(
      appBar: AppBar(title: const Text('حكاية • الطرق الضائعة'), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const Text('حكاية واحدة للعالم كله. فصل جديد كل يوم، أو أسرع لما تبعت بردية.', style: TextStyle(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: done / kChapters.length, minHeight: 6, color: gold, backgroundColor: Colors.white12)),
        const SizedBox(height: 4),
        Text('$done / ${kChapters.length}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 14),
        if (cur >= 0)
          GestureDetector(
            onTap: () => open(cur),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6EACB), Color(0xFFE2CB93)]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📜  الفصل الجاي • Next', style: TextStyle(color: Color(0xFF8A6B2F), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(ar(cur), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF3B2A18), height: 1.3)),
                Text(en(cur), style: const TextStyle(fontSize: 14, color: Color(0xFF5B4630))),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Chip(label: Text('اقرأ • Read'), backgroundColor: Color(0xFFE0B04A))),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        for (var i = 0; i < kChapters.length; i++)
          if (i != cur)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFF10294A), borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: i < done ? gold : Colors.white10, child: i < done ? const Icon(Icons.check, color: Colors.black87) : (i < un ? Text('${i}', style: const TextStyle(color: gold)) : const Icon(Icons.lock, size: 18, color: Colors.white38))),
                title: Text(ar(i), style: TextStyle(fontWeight: FontWeight.w700, color: i < un ? Colors.white : Colors.white38)),
                subtitle: Text(i < un ? en(i) : 'يفتح بكرة، أو ابعت بردية', style: TextStyle(fontSize: 12, color: i < un ? Colors.white60 : Colors.white30)),
                onTap: i < un ? () => open(i) : null,
              ),
            ),
        const SizedBox(height: 6),
        const Text('الترجمة الآلية ممكن تغلط.', style: TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}

class ChapterPage extends StatelessWidget {
  final int i;
  const ChapterPage({super.key, required this.i});
  @override
  Widget build(BuildContext context) {
    final c = kChapters[i];
    return Scaffold(
      appBar: AppBar(title: Text(c[0] as String, style: const TextStyle(fontSize: 15)), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Directionality(textDirection: TextDirection.ltr, child: Text(c[2] as String, style: const TextStyle(fontSize: 17, height: 1.65, color: Color(0xFF3B2A18), fontFamily: 'serif'))),
            const Divider(color: Color(0xFF9B7B4B)),
            Directionality(textDirection: TextDirection.rtl, child: Text(c[3] as String, style: const TextStyle(fontSize: 17, height: 1.8, color: Color(0xFF3B2A18)))),
          ]),
        ),
        const SizedBox(height: 20),
        Text(c[4] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final o in c[5] as List<String>)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: FilledButton(onPressed: () { Passport.finishChapter(i); toast(context, 'Chapter done. +stamp, +XP'); Navigator.pop(context); }, child: Text(o))),
      ]),
    );
  }
}

class PassportPage extends StatelessWidget {
  const PassportPage({super.key});
  static const gold = Color(0xFFE0B04A);
  @override
  Widget build(BuildContext context) {
    final s = Passport.stamps.where((x) => !x.startsWith('trip-')).toList();
    final countries = <String>{for (final x in s) if (x.startsWith('word-') || x.startsWith('home-')) x.substring(x.indexOf('-') + 1)};
    final trust = math.min(100, 20 + Passport.streak * 3 + Passport.papyri * 2);
    Widget tile(String icon, String v, String l) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF12304F), border: Border.all(color: gold.withOpacity(.5)), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(icon, style: const TextStyle(fontSize: 20)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: gold)), Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white70))]),
      ),
    );
    final ach = <List<Object>>[
      ['🔥', 'Streak 3 days', Passport.streak >= 3],
      ['📜', 'First papyrus', Passport.papyri >= 1],
      ['🌍', '3 countries explored', countries.length >= 3],
      ['✍️', '10 papyri', Passport.papyri >= 10],
      ['🏅', '7-day streak', Passport.streak >= 7],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Passport • الباسبور'), backgroundColor: kBg, actions: [
        IconButton(tooltip: 'Tools', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToolsPage())), icon: const Icon(Icons.apps)),
        IconButton(tooltip: 'Settings', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _cover(),
        const SizedBox(height: 12),
        _dataPage(countries.length),
        const SizedBox(height: 10),
        Row(children: [tile('🔥', '${Passport.streak}', 'Streak'), tile('🛡️', '$trust', 'Trust score'), tile('📜', '${Passport.papyri}', 'Papyri sent'), tile('🌍', '${countries.length}', 'Countries explored')]),
        const Padding(padding: EdgeInsets.fromLTRB(4, 2, 4, 0), child: Text('Trust score is a local number from your own streak and papyri. It is not verified by anyone.', style: TextStyle(fontSize: 11, color: Colors.white38))),
        const SizedBox(height: 14),
        const Text('Daily scroll • لفافة اليوم', style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(12)),
          child: Text('Ink left today: ${Passport.ink}/10. Catch papyri, send one, keep your streak. Ink refills at 12:00.', style: const TextStyle(color: Color(0xFF5B4630))),
        ),
        const SizedBox(height: 14),
        const Text('Achievements • إنجازات', style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in ach) Opacity(opacity: a[2] == true ? 1 : .35, child: Chip(avatar: Text(a[0] as String), label: Text(a[1] as String))),
        ]),
        const SizedBox(height: 14),
        const Text('Stamps • أختام', style: TextStyle(fontWeight: FontWeight.w700, color: gold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF1E3C3), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            if (s.isEmpty) const Text('No stamps yet. Pick a country, solve the daily puzzle, learn a word, or send a papyrus.', style: TextStyle(color: Color(0xFF5B4630))),
            Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < s.length; i++) _stamp(s[i], i)]),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Stored on this phone only. Stamps are for fun.', style: TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
    );
  }
  Widget _cover() => Container(
    height: 170,
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16406B), Color(0xFF0B2542)]),
      border: Border.all(color: gold, width: 2.5), borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: gold.withOpacity(.5)), borderRadius: BorderRadius.circular(10)),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('𓂀', style: TextStyle(fontSize: 44, color: gold)),
        SizedBox(height: 4),
        Text('NILO', style: TextStyle(fontSize: 26, letterSpacing: 10, color: gold, fontWeight: FontWeight.w800)),
        Text('TRAVEL PASSPORT', style: TextStyle(fontSize: 13, letterSpacing: 4, color: gold)),
        Text('جواز سفر نيلو', style: TextStyle(fontSize: 15, color: gold)),
      ]),
    ),
  );

  Widget _dataPage(int nCountries) {
    const ink = Color(0xFF3B2F1E);
    final nick = Passport.nickname.isEmpty ? 'TRAVELLER' : Passport.nickname.toUpperCase();
    final c = Passport.country.isEmpty ? null : countryOf(Passport.country);
    final start = DateTime(2026, 1, 1).add(Duration(days: Passport.startDay));
    const mo = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final issued = '${start.day.toString().padLeft(2, '0')} ${mo[start.month - 1]} ${start.year}';
    final no = 'NL${(Passport.nickname.hashCode.abs() % 9000000 + 1000000)}';
    String mrz(String t) => t.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '<').padRight(30, '<').substring(0, 30);
    Widget f(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 9, color: Color(0xFF8A7650), letterSpacing: 1)), Text(v, style: const TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w700))]));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6EACB), Color(0xFFE9D7AA)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB89A55), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('PASSPORT • جواز', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFF8A7650))), Text('NILO', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Color(0xFF8A7650), fontWeight: FontWeight.w800))]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 90, height: 112,
            decoration: BoxDecoration(color: const Color(0xFFD8C690), border: Border.all(color: const Color(0xFFB89A55)), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(c == null ? '𓂀' : '${c[3]}', style: const TextStyle(fontSize: 46))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            f('NAME / الاسم', nick),
            f('COUNTRY / البلد', c == null ? 'NOT SET' : '${c[1]}'.toUpperCase()),
            f('DATE OF ISSUE', issued),
            f('PASSPORT NO.', no),
          ])),
        ]),
        const SizedBox(height: 6),
        Text('${mrz('P<NIL<<$nick')}\n${mrz('$no<${Passport.xp}XP<${Passport.streak}D<$nCountries')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: ink, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text('Fun travel passport inside the Nilo app. Not a government document.', style: TextStyle(fontSize: 9, color: Color(0xFF8A7650))),
      ]),
    );
  }

  Widget _stamp(String x, int i) {
    final col = [const Color(0xFF9B2C2C), const Color(0xFF1E4E8C), const Color(0xFF2C6B3F)][i % 3];
    final parts = _label(x).split(' ');
    final icon = parts.first;
    final name = parts.skip(1).join(' ');
    return Transform.rotate(
      angle: ((i * 7) % 11 - 5) * 0.06,
      child: Container(
        width: 92, height: 92, padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: i % 4 == 3 ? BoxShape.rectangle : BoxShape.circle, borderRadius: i % 4 == 3 ? BorderRadius.circular(8) : null, border: Border.all(color: col.withOpacity(.85), width: 3)),
        child: Container(
          decoration: BoxDecoration(shape: i % 4 == 3 ? BoxShape.rectangle : BoxShape.circle, borderRadius: i % 4 == 3 ? BorderRadius.circular(6) : null, border: Border.all(color: col.withOpacity(.7), width: 1)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.w800)),
            Text('NILO', style: TextStyle(fontSize: 8, letterSpacing: 2, color: col.withOpacity(.8))),
          ]),
        ),
      ),
    );
  }

  static String _label(String x) {
    if (x.startsWith('home-')) return '🏠 ${countryOf(x.substring(5))[1]}';
    if (x.startsWith('word-')) return '💬 ${countryOf(x.substring(5))[1]}';
    if (x.startsWith('chapter-')) return '📖 Chapter ${int.parse(x.substring(8)) + 1}';
    if (x.startsWith('trip-')) return '📜 ${countryOf(x.substring(5))[1]}';
    return '🧩 Puzzle';
  }
}

/// Animated world-map trip of a papyrus. Cosmetic animation: it flies to a random country, the real reader is whoever catches it.
class PapyrusTripPage extends StatefulWidget {
  const PapyrusTripPage({super.key});
  @override
  State<PapyrusTripPage> createState() => _PapyrusTripPageState();
}

class _PapyrusTripPageState extends State<PapyrusTripPage> with TickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 12))..forward();
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  @override
  void initState() {
    super.initState();
    Passport.papyrusSent();
    _a.addListener(() { if (_a.value > 0.97 && mounted) setState(() {}); });
  }
  @override
  void dispose() { _a.dispose(); _spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('رحلة بردييتك • Your papyrus'), backgroundColor: kBg),
        body: Column(children: [
          Expanded(child: RepaintBoundary(child: AnimatedBuilder(animation: Listenable.merge([_a, _spin]), builder: (_, __) => CustomPaint(size: Size.infinite, painter: GlobePainter(_a.value, _spin.value))))),
          Padding(padding: const EdgeInsets.all(16), child: Text(
            _a.value < 0.45 ? '📜 بتبحر في النيل • Sailing down the Nile' : (_a.value < 0.97 ? '🌍 بتطلع للبحر • Drifting out to sea' : 'بردييتك في البحر. هتوصل لحد حقيقي يلاقيها.\nAdrift. It lands with a real person who catches it.'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Real map outlines (Natural Earth, public domain). The route is an animation: we do not know who will catch it or where they live. When someone replies, you will see it in your inbox.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white54))),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          const SizedBox(height: 16),
        ]),
      );
}

/// Animated background: deep gradient, moving Nile waves and drifting gold dust. Pure Flutter, no assets.
class NileBackground extends StatefulWidget {
  const NileBackground({super.key});
  @override
  State<NileBackground> createState() => _NileBackgroundState();
}

class _NileBackgroundState extends State<NileBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(size: Size.infinite, painter: _BgPainter(_c.value)))),
      );
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    final h = DateTime.now().hour;
    final night = h >= 19 || h < 5;
    final dusk = (h >= 17 && h < 19) || (h >= 5 && h < 7);
    final cols = night
        ? const [Color(0xFF050E1A), Color(0xFF0A1B30), Color(0xFF0E2A45)]
        : dusk
            ? const [Color(0xFF2A2548), Color(0xFF7A4A55), Color(0xFFB87A4B)]
            : const [Color(0xFF1B4F7A), Color(0xFF2E7BA6), Color(0xFF5BA6C4)];
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: cols).createShader(rect));
    if (night) {
      final star = Paint()..color = Colors.white.withOpacity(0.55);
      for (var i = 0; i < 40; i++) {
        final tw = 0.4 + 0.6 * ((math.sin(t * 2 * math.pi * 2 + i) + 1) / 2);
        canvas.drawCircle(Offset((i * 37 % 100) / 100 * s.width, (i * 61 % 100) / 100 * s.height * 0.55), 0.8 + (i % 3) * 0.4, star..color = Colors.white.withOpacity(0.5 * tw));
      }
      canvas.drawCircle(Offset(s.width * 0.82, s.height * 0.1), 18, Paint()..color = const Color(0xFFF3E9C6));
    } else {
      canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.045), dusk ? 30 : 24, Paint()..color = (dusk ? const Color(0xFFFFB066) : const Color(0xFFFFE9A8)).withOpacity(0.9));
    }
    final tau = 2 * math.pi;
    for (var i = 0; i < 3; i++) {
      final base = s.height * (0.80 + i * 0.07);
      final amp = 14.0 + i * 5;
      final path = Path()..moveTo(0, s.height);
      for (var x = 0.0; x <= s.width; x += 8) {
        path.lineTo(x, base + math.sin((x / s.width * 2 + t * (i.isEven ? 1 : -1)) * tau) * amp);
      }
      path..lineTo(s.width, s.height)..close();
      canvas.drawPath(path, Paint()..color = Color.fromRGBO(30 + i * 15, 90 + i * 20, 130 + i * 15, 0.22));
    }
    final dust = Paint()..color = const Color(0x33D9A441);
    for (var i = 0; i < 24; i++) {
      final px = (i * 97 % 100) / 100 * s.width;
      final py = ((i * 53 % 100) / 100 + t * (0.15 + (i % 5) * 0.03)) % 1.0 * s.height * 0.8;
      canvas.drawCircle(Offset(px + math.sin(t * tau + i) * 10, py), 1.2 + (i % 3) * 0.6, dust);
    }
  }
  @override
  bool shouldRepaint(_BgPainter o) => o.t != t;
}

/// Home tile with gradient, glow icon, press scale and haptic.
class NiloTile extends StatefulWidget {
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  const NiloTile({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  State<NiloTile> createState() => _NiloTileState();
}

class _NiloTileState extends State<NiloTile> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
        child: AnimatedScale(
          scale: down ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF173A5E), Color(0xFF0F2A47)]),
              border: Border.all(color: kGreen.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle, color: kGreen.withOpacity(0.16), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.25), blurRadius: 12)]),
                child: Icon(widget.icon, color: kGreen, size: 22),
              ),
              const SizedBox(height: 8),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(widget.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.25)),
            ]),
          ),
        ),
      );
}

/// Nai, the small guide: gold circle with a quill, speech bubble.
class NaiSays extends StatelessWidget {
  final String en, ar;
  const NaiSays({super.key, required this.en, required this.ar});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFB8860B)]), boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 14)]),
          child: const Text('🪶', style: TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF12304D), border: Border.all(color: kGreen.withOpacity(0.5)), borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nai • ناي', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 4),
            Text(en, style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Text(ar, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
          ]),
        )),
      ]);
}

/// First-run story: a papyrus drifts down the Nile, Nai asks where it found you, then nickname, 18+ and a first stamp.
class FirstRunPage extends StatefulWidget {
  final Widget next;
  const FirstRunPage({super.key, required this.next});
  @override
  State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  bool busy = true, adult = false;
  String code = '';
  final nick = TextEditingController();
  @override
  void initState() { super.initState(); _auto(); }
  @override
  void dispose() { _a.dispose(); nick.dispose(); super.dispose(); }

  /// Quiet detection from the mobile network / SIM, no permission and no location.
  Future<void> _auto() async {
    final cc = await detectCountry(allowGps: false);
    if (!mounted) return;
    setState(() { busy = false; if (kWorld.any((c) => c[0] == cc)) code = cc; });
  }

  Future<void> _gps() async {
    setState(() => busy = true);
    final cc = await detectCountry(allowGps: true);
    if (!mounted) return;
    setState(() { busy = false; if (kWorld.any((c) => c[0] == cc)) code = cc; });
    if (!kWorld.any((c) => c[0] == cc)) toast(context, 'Could not detect. Tap the flag to choose.');
  }

  Future<void> _choose() async {
    final r = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CountryPickerPage()));
    if (!mounted) return;
    if (r == true && Passport.country.isNotEmpty) setState(() => code = Passport.country);
  }

  void _rules() => showModalBottomSheet(context: context, backgroundColor: const Color(0xFF12304D), builder: (_) => const Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rules • القواعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kGreen)),
          SizedBox(height: 10),
          Text('• 18+ only. Self-declared: Nilo cannot check your age.\n• Text only. No links, phone numbers or social handles.\n• Never send money or share bank or ID details.\n• Meet only in public places and tell a friend.\n• Report and block anyone who makes you uncomfortable.\n• Machine translation can be wrong.', style: TextStyle(height: 1.6)),
          SizedBox(height: 10),
          Text('٠ للكبار ١٨+ فقط  ٠ نص بس، من غير لينكات أو أرقام  ٠ متبعتش فلوس  ٠ قابل حد في مكان عام  ٠ بلّغ واحظر أي حد يضايقك', style: TextStyle(height: 1.6, color: Colors.white70)),
        ]),
      ));

  void _finish() {
    if (code.isEmpty) { toast(context, 'Tap the flag to choose your country'); return; }
    if (nick.text.trim().length < 2) { toast(context, 'Choose a nickname (2 to 20 letters)'); return; }
    if (!adult) { toast(context, 'Please confirm you are 18 or older'); return; }
    Passport.country = code;
    Passport.addStamp('home-$code');
    Passport.nickname = nick.text.trim();
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.next));
  }

  @override
  Widget build(BuildContext context) {
    final has = code.isNotEmpty;
    final c = has ? countryOf(code) : null;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        const Positioned.fill(child: NileBackground()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(animation: _a, builder: (_, __) => Transform.translate(offset: Offset(0, math.sin(_a.value * math.pi) * 6), child: const Text('📜', style: TextStyle(fontSize: 46)))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _choose,
                  child: busy
                      ? const SizedBox(height: 96, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : Column(children: [
                          Text(has ? c![3] as String : '🌍', style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 4),
                          Text(has ? 'Welcome from ${c![1]}' : 'Choose your country', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(has ? 'أهلا بيك من ${c![2]}' : 'اختار بلدك', style: const TextStyle(fontSize: 15, color: Colors.white70)),
                          const SizedBox(height: 2),
                          const Text('Not right? Tap to change • مش صح؟ اضغط', style: TextStyle(fontSize: 12, color: kGreen)),
                        ]),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: nick, maxLength: 20, textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18))), hintText: 'Nickname, not your real name • اسم مستعار', counterText: ''),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Checkbox(value: adult, onChanged: (v) => setState(() => adult = v ?? false), visualDensity: VisualDensity.compact),
                  Expanded(child: Text.rich(TextSpan(style: const TextStyle(fontSize: 13), children: [
                    const TextSpan(text: 'I am 18+ and accept the '),
                    WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: GestureDetector(onTap: _rules, child: const Text('rules', style: TextStyle(fontSize: 13, color: kGreen, decoration: TextDecoration.underline)))),
                  ]))),
                ]),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _finish, style: FilledButton.styleFrom(shape: const StadiumBorder()), child: const Text('Get my passport • استلم جوازك', style: TextStyle(fontSize: 16)))),
                TextButton(onPressed: busy ? null : _gps, child: const Text('Detect with my location once • بالموقع مرة', style: TextStyle(fontSize: 12, color: Colors.white54))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Pops back to the home screen after the first-run story when opened from the card.
class _Back extends StatelessWidget {
  const _Back();
  @override
  Widget build(BuildContext context) { WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) Navigator.of(context).pop(); }); return const Scaffold(); }
}
