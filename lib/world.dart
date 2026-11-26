// Nilo World: passport (stamps, XP, streak), home country, daily word/puzzle, chapters, papyrus trip animation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'screens.dart' show toast;

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
  Future<void> _pick() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CountryPickerPage()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = Passport.country;
    if (code.isEmpty) {
      return _box(InkWell(onTap: _pick, child: const Padding(padding: EdgeInsets.all(16),
        child: Row(children: [Text('🌍', style: TextStyle(fontSize: 34)), SizedBox(width: 12), Expanded(child: Text('Pick your home country to start your story\nاختار بلدك وابدأ حكايتك', style: TextStyle(fontSize: 16, height: 1.4))), Icon(Icons.chevron_right)]))));
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
  @override
  Widget build(BuildContext context) {
    final un = Passport.unlocked;
    return Scaffold(
      appBar: AppBar(title: const Text('The Lost Papyrus Routes'), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('One story for the whole world. A new chapter opens each day, or sooner when you send a papyrus. Written by Nilo\'s makers. Machine translation can be wrong.', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        for (var i = 0; i < kChapters.length; i++)
          Card(color: const Color(0xFF12304D), child: ListTile(
            leading: Icon(i < Passport.chapter ? Icons.check_circle : (i < un ? Icons.menu_book : Icons.lock), color: kGreen),
            title: Text(kChapters[i][0] as String),
            subtitle: Text(i < un ? 'Tap to read' : 'Locked. Opens tomorrow, or send a papyrus.'),
            onTap: i < un ? () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterPage(i: i))); if (mounted) setState(() {}); } : null,
          )),
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
        Text(c[2] as String, style: const TextStyle(fontSize: 17, height: 1.6)),
        const SizedBox(height: 14),
        Directionality(textDirection: TextDirection.rtl, child: Text(c[3] as String, style: const TextStyle(fontSize: 17, height: 1.7, color: Colors.white70))),
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
  @override
  Widget build(BuildContext context) {
    final s = Passport.stamps;
    return Scaffold(
      appBar: AppBar(title: const Text('Nilo Passport • الباسبور'), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('⭐ ${Passport.xp} XP   🔥 ${Passport.streak} days   📜 ${Passport.papyri} papyri sent', style: const TextStyle(fontSize: 17)),
        const SizedBox(height: 12),
        if (s.isEmpty) const Text('No stamps yet. Pick a country, solve the daily puzzle, learn a word, or send a papyrus.', style: TextStyle(color: Colors.white70)),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final x in s) Chip(label: Text(_label(x))),
        ]),
        const SizedBox(height: 14),
        const Text('Stored on this phone only. Stamps are for fun.', style: TextStyle(fontSize: 12, color: Colors.white54)),
      ]),
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

class _PapyrusTripPageState extends State<PapyrusTripPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  late final List<Object> from = countryOf(Passport.country.isEmpty ? 'EG' : Passport.country);
  late final List<Object> to = () {
    final l = kWorld.where((c) => c[0] != from[0]).toList();
    return l[math.Random().nextInt(l.length)];
  }();
  @override
  void initState() {
    super.initState();
    Passport.papyrusSent();
    Passport.addStamp('trip-${to[0]}');
    _a.addListener(() { if (_a.value > 0.97 && mounted) setState(() {}); });
  }
  @override
  void dispose() { _a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your papyrus is travelling'), backgroundColor: kBg),
        body: Column(children: [
          Expanded(child: AnimatedBuilder(animation: _a, builder: (_, __) => CustomPaint(size: Size.infinite, painter: _TripPainter(_a.value, from, to)))),
          Padding(padding: const EdgeInsets.all(16), child: Text(
            _a.value < 0.97 ? '📜 ${from[3]} ${from[1]}  →  ${to[1]} ${to[3]}' : '${to[6]} Arrived! In ${to[1]} it becomes: ${to[7]}.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 17))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('The trip is an animation. The person who actually reads your papyrus is whoever catches it, and it may take time.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white54))),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          const SizedBox(height: 16),
        ]),
      );
}

class _TripPainter extends CustomPainter {
  final double t;
  final List<Object> a, b;
  _TripPainter(this.t, this.a, this.b);
  Offset _pt(List<Object> c, Size s) => Offset(((c[5] as double) + 180) / 360 * s.width, (90 - (c[4] as double)) / 180 * s.height);
  @override
  void paint(Canvas canvas, Size s) {
    final dot = Paint()..color = Colors.white12;
    for (final c in kWorld) { canvas.drawCircle(_pt(c, s), 3, dot); }
    final grid = Paint()..color = Colors.white10..strokeWidth = 1;
    for (var i = 1; i < 6; i++) { canvas.drawLine(Offset(0, s.height * i / 6), Offset(s.width, s.height * i / 6), grid); canvas.drawLine(Offset(s.width * i / 6, 0), Offset(s.width * i / 6, s.height), grid); }
    final p0 = _pt(a, s), p1 = _pt(b, s);
    final mid = Offset((p0.dx + p1.dx) / 2, math.min(p0.dy, p1.dy) - s.height * 0.22);
    Offset at(double u) => Offset(
          (1 - u) * (1 - u) * p0.dx + 2 * (1 - u) * u * mid.dx + u * u * p1.dx,
          (1 - u) * (1 - u) * p0.dy + 2 * (1 - u) * u * mid.dy + u * u * p1.dy);
    final path = Paint()..color = kGreen.withOpacity(0.7)..strokeWidth = 2..style = PaintingStyle.stroke;
    final e = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    Offset? prev;
    for (var i = 0; i <= 40; i++) { final u = e * i / 40; final q = at(u); if (prev != null) canvas.drawLine(prev, q, path); prev = q; }
    void label(String txt, Offset o, double size) {
      final tp = TextPainter(text: TextSpan(text: txt, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
    label(a[3] as String, p0, 26);
    label(t < 0.97 ? b[3] as String : b[6] as String, p1, t < 0.97 ? 26 : 40);
    if (t < 0.97) label('📜', at(e), 30);
  }
  @override
  bool shouldRepaint(_TripPainter o) => o.t != t;
}
