import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottles.dart';
import 'challenge.dart';
import 'chain.dart';
import 'calm.dart';
import 'circles.dart' show niloJoined, niloJoinGate;
import 'extras.dart' show niloRoute;
import 'globe.dart' show GlobePage;
import 'i18n.dart';
import 'main.dart';
import 'net.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport, kWorld;

/// One neutral question per day, the same for everyone (picked from the date, no server needed).
const List<List<String>> kDailyQuestions = [
  ['What sound reminds you of home?', 'إيه صوت بيفكرك ببيتك؟'],
  ['What is a small thing that made you smile this week?', 'إيه حاجة صغيرة فرحتك الأسبوع ده؟'],
  ['What food would you cook for a visitor?', 'تطبخ إيه لضيف عندك؟'],
  ['What is one word every traveler to your country should learn?', 'كلمة لازم كل مسافر لبلدك يتعلمها؟'],
  ['What did you want to be when you were ten?', 'كنت عايز تبقى إيه وانت عندك عشر سنين؟'],
  ['Which place near you is worth a visit and why?', 'مكان قريب منك يستاهل الزيارة وليه؟'],
  ['What song do you play when you need energy?', 'أنهي أغنية بتسمعها لما تحتاج طاقة؟'],
  ['What is the best advice you ever got?', 'أحسن نصيحة اتقالتلك؟'],
  ['What smell takes you back to childhood?', 'أنهي ريحة بترجعك لطفولتك؟'],
  ['What do people in your country do on a rainy day?', 'الناس في بلدك بتعمل إيه في يوم مطر؟'],
  ['What is something you are learning right now?', 'بتتعلم إيه دلوقتي؟'],
  ['What would you put in a time capsule for next year?', 'تحط إيه في كبسولة زمن للسنة الجاية؟'],
  ['What is a tradition in your family?', 'إيه تقليد في عيلتك؟'],
  ['Describe your morning in five words.', 'وصف صباحك في خمس كلمات.'],
  ['What is a kind thing a stranger did for you?', 'إيه الحاجة الطيبة اللي عملها غريب معاك؟'],
  ['What is your favorite season and why?', 'فصلك المفضل وليه؟'],
  ['What is one place you want to see before you are 40?', 'مكان نفسك تشوفه قبل ما تبقى 40؟'],
  ['What is the funniest thing that happened to you while traveling?', 'أطرف حاجة حصلتلك في سفر؟'],
  ['What is a skill you wish everyone had?', 'مهارة نفسك الكل يبقى عنده؟'],
  ['What is your comfort drink?', 'مشروبك اللي بيريحك؟'],
  ['What is a game you played as a child?', 'لعبة كنت بتلعبها وانت صغير؟'],
  ['What do you say when you meet someone for the first time?', 'بتقول إيه لما تقابل حد لأول مرة؟'],
  ['What makes a good neighbor?', 'إيه اللي يخلي الجار كويس؟'],
  ['What is something small you are proud of?', 'حاجة صغيرة فخور بيها؟'],
  ['What is the best view you have seen?', 'أحلى منظر شفته؟'],
  ['What would you tell your younger self?', 'تقول إيه لنفسك وانت أصغر؟'],
  ['What is a word in your language that is hard to translate?', 'كلمة في لغتك صعب تتترجم؟'],
  ['What is your favorite time of day?', 'وقتك المفضل في اليوم؟'],
  ['What is one thing you can fix, build or make?', 'حاجة تعرف تصلحها أو تبنيها أو تعملها؟'],
  ['What is a dish you could eat every day?', 'أكلة تاكلها كل يوم؟'],
  ['What is a place that feels like a hug to you?', 'مكان بتحس فيه بالأمان؟'],
  ['What is a compliment you will never forget?', 'مجاملة عمرك ما هتنساها؟'],
  ['What is one thing you would show a friend from another country?', 'حاجة تفرّج عليها صاحبك من بلد تانية؟'],
];

int _dayNumber() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
String _today() => DateTime.now().toUtc().toIso8601String().substring(0, 10);
List<String> todaysQuestion() => kDailyQuestions[_dayNumber() % kDailyQuestions.length];

String _flagOf(String code) {
  for (final w in kWorld) { if (w[0] == code) return w[3] as String; }
  return '🌍';
}

/// Everything playable in one place.
class PlayHubPage extends StatelessWidget {
  const PlayHubPage({super.key});

  Widget _tile(BuildContext c, String emoji, String title, String sub, Widget page) => Card(
        color: const Color(0xFF12304D),
        child: ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 30)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(c).push(niloRoute(page)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(L('Play • العب')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          _tile(context, '❓', L('Question of the day • سؤال اليوم'), L('One question for the whole world. Answer in one line.'), const DailyQuestionPage()),
          _tile(context, '🌴', L('Focus garden • حديقة التركيز'), L('Focus 10 or 25 minutes, a palm grows.'), const FocusPage()),
          _tile(context, '🌤️', L('Mood sky • سما المزاج'), L('How does today feel? A private journal.'), const MoodSkyPage()),
          _tile(context, '🧵', L('Pass it on • مرّرها'), L('A story written by 6 strangers, one line each.'), const PassItOnPage()),
          _tile(context, '🗓️', L('Weekly challenge • تحدي الأسبوع'), L('One real-life task a week, plus your own recipe corner.'), const WeeklyChallengePage()),
          _tile(context, '🌐', L('Nilo Globe • كورة نيلو'), L('Turn the Earth, fly a papyrus, see landmarks.'), const GlobePage()),
          _tile(context, '🛂', L('Stamp book • كتاب الأختام'), L('Countries you opened on the Globe.'), const StampBookPage()),
          _tile(context, '🔠', L('Your name in the world • اسمك في العالم'), L('See your name in other scripts.'), const NameScriptsPage()),
          _tile(context, '🌅', L('Sky card • كارت السما'), L('Is the sun up in your country right now?'), const SunCardPage()),
          _tile(context, '📖', L('My word book • كتاب كلماتي'), L('Words people taught you in papyri.'), const WordBookPage()),
          const SizedBox(height: 10),
          Text(L('In a papyrus: tap 🔤 to swap a word, or 🎭 for Two truths and a lie.\nجوه البردية: دوس 🔤 لتبادل كلمة، أو 🎭 لحقيقتين وكذبة.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
        ]),
      );
}

/// Question of the day: one line per person per day, a public board you can filter by your country. 18+, no links or numbers.
class DailyQuestionPage extends StatefulWidget {
  const DailyQuestionPage({super.key});
  @override
  State<DailyQuestionPage> createState() => _DailyQuestionPageState();
}

class _DailyQuestionPageState extends State<DailyQuestionPage> {
  bool joined = false, busy = true, mineOnly = false;
  List<dynamic> rows = [];
  String err = '';
  final c = TextEditingController();
  final Map<String, String> tr = {};

  bool get answered => rows.any((r) => (r as Map)['author'] == Sb.uid);

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { c.dispose(); super.dispose(); }

  Future<void> _init() async {
    joined = await niloJoined();
    if (joined) { await _load(); } else if (mounted) { setState(() => busy = false); }
  }

  Future<void> _load() async {
    setState(() { busy = true; err = ''; });
    try {
      if (!await Sb.signIn()) throw Exception('offline');
      final cc = Passport.country;
      final f = mineOnly && cc.isNotEmpty ? '&country=eq.$cc' : '';
      rows = await Sb.get('daily_answers?select=*&day=eq.${_today()}$f&order=created_at.desc&limit=60') as List;
    } catch (_) { err = 'Could not load. Check your connection.'; }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _send() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least 3 letters.'); return; }
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    final p = await SharedPreferences.getInstance();
    try {
      await Sb.post('daily_answers', {'author': Sb.uid, 'nick': p.getString('b_nick') ?? 'Traveler', 'country': Passport.country, 'body': t});
      c.clear();
      FocusScope.of(context).unfocus();
      _load();
    } catch (_) {
      if (mounted) toast(context, 'Not sent. One answer a day, no links or phone numbers.');
    }
  }

  Future<void> _menu(Map s) async {
    final mine = s['author'] == Sb.uid;
    final v = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E2A45), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: Text(L('Delete')), onTap: () => Navigator.pop(context, 'del'))
      else ...[
        ListTile(leading: const Icon(Icons.flag_outlined), title: Text(L('Report')), onTap: () => Navigator.pop(context, 'rep')),
        ListTile(leading: const Icon(Icons.block), title: Text(L('Block this person')), onTap: () => Navigator.pop(context, 'blk')),
      ],
    ])));
    if (v == null) return;
    try {
      if (v == 'del') await Sb.delete('daily_answers?id=eq.${s['id']}');
      if (v == 'rep') { await Sb.rpc('report_daily_answer', {'pid': s['id']}); if (mounted) toast(context, 'Reported. Thank you.'); }
      if (v == 'blk') { await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': s['author']}); if (mounted) toast(context, 'Blocked.'); }
      _load();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  Future<void> _translate(String id, String text) async {
    final r = await trText(text, 'auto', Ui.lang == 'ar' ? 'ar' : 'en');
    if (!mounted) return;
    if (r.ok) { setState(() => tr[id] = r.translation); } else { toast(context, r.error.isEmpty ? 'Translation failed' : r.error); }
  }

  @override
  Widget build(BuildContext context) {
    final q = todaysQuestion();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, title: Text(L('Question of the day • سؤال اليوم')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: !joined
          ? (busy ? const Center(child: CircularProgressIndicator()) : niloJoinGate(context, _init))
          : Column(children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1C4A6E), Color(0xFF12304D)]), borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(q[0], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(q[1], textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4)),
                ]),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ChoiceChip(label: Text(L('Whole world • كل العالم')), selected: !mineOnly, onSelected: (_) { setState(() => mineOnly = false); _load(); }),
                const SizedBox(width: 8),
                ChoiceChip(label: Text('${_flagOf(Passport.country)} ${L('My country • بلدي')}'), selected: mineOnly, onSelected: (_) { setState(() => mineOnly = true); _load(); }),
              ]),
              Expanded(
                child: busy
                    ? const Center(child: CircularProgressIndicator())
                    : err.isNotEmpty
                        ? Center(child: Text(L(err)))
                        : rows.isEmpty
                            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(L('No answers yet today. Be the first.\nمفيش إجابات النهارده لسه. كن أول واحد.'), textAlign: TextAlign.center)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: rows.length,
                                itemBuilder: (_, i) {
                                  final s = Map<String, dynamic>.from(rows[i] as Map);
                                  final id = s['id'].toString();
                                  final body = (s['body'] ?? '').toString();
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(16)),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text('${_flagOf((s['country'] ?? '').toString())} ${s['nick']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const Spacer(),
                                        InkWell(onTap: () => _menu(s), child: const Icon(Icons.more_vert, color: Colors.white54, size: 20)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(body, style: const TextStyle(height: 1.4, fontSize: 15)),
                                      if (tr[id] != null) Text(tr[id]!, style: const TextStyle(color: kGreen, height: 1.4)),
                                      if (tr[id] == null && s['author'] != Sb.uid) InkWell(onTap: () => _translate(id, body), child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(L('Translate (machine, may be wrong)'), style: const TextStyle(fontSize: 11, color: Colors.white54)))),
                                    ]),
                                  );
                                },
                              ),
              ),
              if (!busy && !answered)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Row(children: [
                      Expanded(child: TextField(controller: c, maxLength: 200, maxLines: 2, minLines: 1, decoration: InputDecoration(counterText: '', hintText: L('Your answer, one line • إجابتك في سطر'), border: const OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                    ]),
                  ),
                ),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(L('18+. One answer a day. No links, emails or phone numbers. Report anything wrong.'), style: const TextStyle(fontSize: 10, color: Colors.white38))),
            ]),
    );
  }
}

/// Words people taught you through Word Swap in a papyrus. Stored on this phone only.
Future<List<Map<String, String>>> loadWordBook() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('word_book') ?? '[]';
  try {
    return (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e as Map)).toList();
  } catch (_) { return []; }
}

Future<void> saveWord(String word, String meaning) async {
  final p = await SharedPreferences.getInstance();
  final l = await loadWordBook();
  if (l.any((e) => e['w'] == word)) return;
  l.insert(0, {'w': word, 'm': meaning});
  await p.setString('word_book', jsonEncode(l.take(300).toList()));
}

class WordBookPage extends StatefulWidget {
  const WordBookPage({super.key});
  @override
  State<WordBookPage> createState() => _WordBookPageState();
}

class _WordBookPageState extends State<WordBookPage> {
  List<Map<String, String>> items = [];
  @override
  void initState() { super.initState(); loadWordBook().then((l) { if (mounted) setState(() => items = l); }); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(L('My word book • كتاب كلماتي')), backgroundColor: kBg),
        body: items.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(L('Empty for now. In a papyrus tap 🔤 to swap a word, then save the one you receive.\nفاضي لسه. جوه البردية دوس 🔤 لتبادل كلمة، وبعدين احفظ الكلمة اللي توصلك.'), textAlign: TextAlign.center, style: const TextStyle(height: 1.5))))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final e in items)
                  Card(color: const Color(0xFF12304D), child: ListTile(title: Text(e['w']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), subtitle: Text(e['m']!))),
              ]),
      );
}

/// Stamp book: every country you opened on the Nilo Globe, kept on this phone only.
class StampBookPage extends StatefulWidget {
  const StampBookPage({super.key});
  @override
  State<StampBookPage> createState() => _StampBookPageState();
}

class _StampBookPageState extends State<StampBookPage> {
  Set<String> got = {};
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) { if (mounted) setState(() => got = (p.getStringList('globe_stamps') ?? <String>[]).toSet()); });
  }

  @override
  Widget build(BuildContext context) {
    final n = got.length;
    final badges = [[5, '🥉'], [15, '🥈'], [40, '🥇'], [80, '🏆']];
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Stamp book • كتاب الأختام')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text('$n / ${kWorld.length}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final b in badges) Padding(padding: const EdgeInsets.all(6), child: Opacity(opacity: n >= (b[0] as int) ? 1 : 0.25, child: Column(children: [Text(b[1] as String, style: const TextStyle(fontSize: 30)), Text('${b[0]}', style: const TextStyle(fontSize: 11))]))),
        ]),
        const SizedBox(height: 8),
        Text(L('Open a country on the Globe to collect its stamp. Stored on this phone only.\nافتح دولة على الكورة عشان تاخد ختمها. محفوظ على موبايلك بس.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.5)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final w in kWorld)
            Opacity(opacity: got.contains(w[0]) ? 1 : 0.22, child: Container(
              width: 62, padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(12), border: got.contains(w[0]) ? Border.all(color: Colors.amberAccent) : null),
              child: Column(children: [Text(w[3] as String, style: const TextStyle(fontSize: 26)), Text(w[0] as String, style: const TextStyle(fontSize: 10))]),
            )),
        ]),
      ]),
    );
  }
}

/// Your name in other scripts. Offline, sound-based and approximate: a fun card, not an official transliteration.
class NameScriptsPage extends StatefulWidget {
  const NameScriptsPage({super.key});
  @override
  State<NameScriptsPage> createState() => _NameScriptsPageState();
}

class _NameScriptsPageState extends State<NameScriptsPage> {
  final c = TextEditingController();
  static const _ar = {'a': 'ا', 'b': 'ب', 'c': 'ك', 'd': 'د', 'e': 'ي', 'f': 'ف', 'g': 'ج', 'h': 'ه', 'i': 'ي', 'j': 'ج', 'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'o': 'و', 'p': 'ب', 'q': 'ق', 'r': 'ر', 's': 'س', 't': 'ت', 'u': 'و', 'v': 'ف', 'w': 'و', 'x': 'كس', 'y': 'ي', 'z': 'ز'};
  static const _cy = {'a': 'а', 'b': 'б', 'c': 'к', 'd': 'д', 'e': 'е', 'f': 'ф', 'g': 'г', 'h': 'х', 'i': 'и', 'j': 'дж', 'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н', 'o': 'о', 'p': 'п', 'q': 'к', 'r': 'р', 's': 'с', 't': 'т', 'u': 'у', 'v': 'в', 'w': 'в', 'x': 'кс', 'y': 'й', 'z': 'з'};
  static const _gr = {'a': 'α', 'b': 'β', 'c': 'κ', 'd': 'δ', 'e': 'ε', 'f': 'φ', 'g': 'γ', 'h': 'η', 'i': 'ι', 'j': 'τζ', 'k': 'κ', 'l': 'λ', 'm': 'μ', 'n': 'ν', 'o': 'ο', 'p': 'π', 'q': 'κ', 'r': 'ρ', 's': 'σ', 't': 'τ', 'u': 'ου', 'v': 'β', 'w': 'ου', 'x': 'ξ', 'y': 'υ', 'z': 'ζ'};
  static const _hi = {'a': 'अ', 'b': 'ब', 'c': 'क', 'd': 'द', 'e': 'ए', 'f': 'फ', 'g': 'ग', 'h': 'ह', 'i': 'इ', 'j': 'ज', 'k': 'क', 'l': 'ल', 'm': 'म', 'n': 'न', 'o': 'ओ', 'p': 'प', 'q': 'क', 'r': 'र', 's': 'स', 't': 'त', 'u': 'उ', 'v': 'व', 'w': 'व', 'x': 'क्स', 'y': 'य', 'z': 'ज'};
  static const _ka = {'a': 'ア', 'b': 'ブ', 'c': 'ク', 'd': 'ド', 'e': 'エ', 'f': 'フ', 'g': 'グ', 'h': 'ハ', 'i': 'イ', 'j': 'ジ', 'k': 'ク', 'l': 'ル', 'm': 'ム', 'n': 'ン', 'o': 'オ', 'p': 'プ', 'q': 'ク', 'r': 'ル', 's': 'ス', 't': 'ト', 'u': 'ウ', 'v': 'ブ', 'w': 'ワ', 'x': 'クス', 'y': 'ヤ', 'z': 'ズ'};

  String _map(String s, Map<String, String> m) => s.toLowerCase().split('').map((ch) => m[ch] ?? (ch == ' ' ? ' ' : '')).join();

  @override
  void dispose() { c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final name = c.text.trim();
    final isLatin = RegExp(r'^[A-Za-z ]+$').hasMatch(name);
    final rows = <List<String>>[];
    if (isLatin) {
      rows.addAll([
        ['Arabic • عربي', _map(name, _ar)],
        ['Cyrillic • кириллица', _map(name, _cy)],
        ['Greek • Ελληνικά', _map(name, _gr)],
        ['Hindi • हिन्दी', _map(name, _hi)],
        ['Katakana • カタカナ', _map(name, _ka)],
      ]);
    }
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Your name in the world • اسمك في العالم')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        TextField(controller: c, maxLength: 24, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: L('Type your name in English letters'), border: const OutlineInputBorder())),
        if (name.isNotEmpty && !isLatin) Text(L('Use English letters only for now.'), style: const TextStyle(color: Colors.orangeAccent)),
        for (final r in rows)
          Card(color: const Color(0xFF12304D), child: ListTile(
            title: Text(r[1], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            subtitle: Text(r[0], style: const TextStyle(fontSize: 11)),
            trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: r[1])); toast(context, L('Copied')); }),
          )),
        const SizedBox(height: 10),
        Text(L('Sound-based and approximate, made on your phone. It is a fun card, not an official transliteration.\nحسب النطق وتقريبي. للمتعة مش ترجمة رسمية.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.5)),
      ]),
    );
  }
}

/// Is the sun up in your country right now? Solar elevation computed on the phone from the clock and the country's centre. No GPS.
class SunCardPage extends StatelessWidget {
  const SunCardPage({super.key});

  static double elevation(double lat, double lon, DateTime utc) {
    final d = utc.difference(DateTime.utc(utc.year, 1, 1)).inMinutes / 1440.0;
    final g = 2 * math.pi / 365 * d;
    final decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g);
    final eqt = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g));
    final mins = utc.hour * 60.0 + utc.minute + eqt + 4 * lon;
    final ha = (mins / 4 - 180) * math.pi / 180;
    final la = lat * math.pi / 180;
    final s = math.sin(la) * math.sin(decl) + math.cos(la) * math.cos(decl) * math.cos(ha);
    return math.asin(s.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  @override
  Widget build(BuildContext context) {
    final cc = Passport.country.isEmpty ? 'EG' : Passport.country;
    final w = kWorld.firstWhere((x) => x[0] == cc, orElse: () => kWorld.first);
    final el = elevation((w[4] as num).toDouble(), (w[5] as num).toDouble(), DateTime.now().toUtc());
    final phase = el > 6 ? '☀️' : el > -6 ? '🌅' : '🌙';
    final en = el > 6 ? 'The sun is up' : el > -6 ? 'Sunrise or sunset light' : 'It is night';
    final ar = el > 6 ? 'الشمس طالعة' : el > -6 ? 'شروق أو غروب' : 'ليل';
    final line = '${w[3]} ${w[1]} • $en • $ar';
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Sky card • كارت السما')), backgroundColor: kBg),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: el > 6 ? [const Color(0xFF4FA3E0), const Color(0xFFBFE3F7)] : el > -6 ? [const Color(0xFF5B3A70), const Color(0xFFF2A65A)] : [const Color(0xFF050E1C), const Color(0xFF1C2E5A)]),
              ),
              child: Column(children: [
                Text(phase, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text('${w[3]} ${Ui.rtl ? w[2] : w[1]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                Text(Ui.rtl ? ar : en, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text('${L('Sun height')}: ${el.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: '$line (Nilo)')); toast(context, L('Copied. Paste it anywhere you like.')); }, icon: const Icon(Icons.copy), label: Text(L('Copy as text'))),
            const SizedBox(height: 10),
            Text(L('Computed on your phone from the clock and your country. No location is used.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      ),
    );
  }
}
