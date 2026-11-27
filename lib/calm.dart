import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport;

/// Solo pages. Everything stays on the phone: no account, no server.

String _today() => DateTime.now().toIso8601String().substring(0, 10);

/// Focus garden: start a 10 or 25 minute session; when the time is up a palm grows in your garden and you get 3 Reeds.
/// Honor system: the timer keeps running if you leave the page, the palm counts when the end time has passed.
class FocusPage extends StatefulWidget {
  const FocusPage({super.key});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  int trees = 0, endMs = 0;
  Timer? t;

  @override
  void initState() { super.initState(); _load(); t = Timer.periodic(const Duration(seconds: 1), (_) => _tick()); }

  @override
  void dispose() { t?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    trees = p.getInt('focus_trees') ?? 0;
    endMs = p.getInt('focus_end') ?? 0;
    await _tick();
  }

  Future<void> _tick() async {
    if (endMs > 0 && DateTime.now().millisecondsSinceEpoch >= endMs) {
      final p = await SharedPreferences.getInstance();
      trees = (p.getInt('focus_trees') ?? 0) + 1;
      await p.setInt('focus_trees', trees);
      await p.remove('focus_end');
      endMs = 0;
      Passport.addReeds(3);
      if (mounted) toast(context, 'Done. A palm grew. +3 Reeds. • نخلة جديدة');
    }
    if (mounted) setState(() {});
  }

  Future<void> _start(int min) async {
    final p = await SharedPreferences.getInstance();
    endMs = DateTime.now().add(Duration(minutes: min)).millisecondsSinceEpoch;
    await p.setInt('focus_end', endMs);
    setState(() {});
  }

  Future<void> _cancel() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('focus_end');
    setState(() => endMs = 0);
  }

  @override
  Widget build(BuildContext context) {
    final left = endMs > 0 ? Duration(milliseconds: (endMs - DateTime.now().millisecondsSinceEpoch).clamp(0, 1 << 40)) : Duration.zero;
    final mm = left.inMinutes.toString().padLeft(2, '0'), ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Focus garden • حديقة التركيز')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Text(endMs > 0 ? '$mm:$ss' : '🌱', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900))),
        const SizedBox(height: 12),
        if (endMs == 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton(onPressed: () => _start(10), child: Text(L('10 min'))),
          const SizedBox(width: 12),
          FilledButton(onPressed: () => _start(25), child: Text(L('25 min'))),
        ]) else Center(child: OutlinedButton(onPressed: _cancel, child: Text(L('Stop • وقف')))),
        const SizedBox(height: 8),
        Text(L('Put the phone down and do one thing. When the time is up a palm grows.\nسيب الموبايل واشتغل في حاجة واحدة. لما الوقت يخلص بتطلع نخلة.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.5)),
        const SizedBox(height: 20),
        Text('${L('Your garden • حديقتك')}: $trees', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(children: [for (var i = 0; i < trees.clamp(0, 120); i++) const Text('🌴', style: TextStyle(fontSize: 26))]),
      ]),
    );
  }
}

/// Mood sky: choose how today feels, the sky changes, add one line. A private journal on the phone.
class MoodSkyPage extends StatefulWidget {
  const MoodSkyPage({super.key});
  @override
  State<MoodSkyPage> createState() => _MoodSkyPageState();
}

const _moods = <List<Object>>[
  ['☀️', 'Bright • مشرق', Color(0xFFF2B33D), Color(0xFF3FA7E0)],
  ['⛅', 'Okay • عادي', Color(0xFF9DB7C9), Color(0xFF3B6A8C)],
  ['🌧️', 'Heavy • تقيل', Color(0xFF4A5A6A), Color(0xFF1F2A36)],
  ['🌅', 'Hopeful • متفائل', Color(0xFFE88A5C), Color(0xFF6B3B7A)],
  ['🌙', 'Calm • هادي', Color(0xFF3A4A8C), Color(0xFF0B1230)],
  ['⛈️', 'Stormy • متوتر', Color(0xFF3A2C4A), Color(0xFF111018)],
];

class _MoodSkyPageState extends State<MoodSkyPage> {
  int sel = 0;
  List log = [];
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try { log = jsonDecode(p.getString('mood_log') ?? '[]') as List; } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    log.removeWhere((e) => e['d'] == _today());
    log.insert(0, {'d': _today(), 'm': sel, 'n': c.text.trim()});
    if (log.length > 90) log = log.sublist(0, 90);
    await p.setString('mood_log', jsonEncode(log));
    c.clear();
    if (mounted) { toast(context, 'Saved on your phone only. • اتحفظت'); setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    final m = _moods[sel];
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Mood sky • سما المزاج')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          height: 160,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [m[3] as Color, m[2] as Color])),
          child: Center(child: Text(m[0] as String, style: const TextStyle(fontSize: 64))),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [for (var i = 0; i < _moods.length; i++) ChoiceChip(label: Text('${_moods[i][0]} ${(_moods[i][1] as String).split(' • ')[Ui.rtl ? 1 : 0]}'), selected: sel == i, onSelected: (_) => setState(() => sel = i))]),
        const SizedBox(height: 10),
        TextField(controller: c, maxLength: 120, decoration: InputDecoration(hintText: L('One line about today (optional) • سطر عن النهارده'), border: const OutlineInputBorder())),
        FilledButton(onPressed: _save, child: Text(L('Save today • احفظ'))),
        const SizedBox(height: 6),
        Text(L('Private. Stays on this phone, never sent anywhere.'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 14),
        Text(L('Journal • اليوميات'), style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final e in log.take(30))
          ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Text(_moods[(e['m'] as num).toInt().clamp(0, 5)][0] as String, style: const TextStyle(fontSize: 24)), title: Text((e['n'] ?? '').toString().isEmpty ? '—' : e['n'].toString()), subtitle: Text(e['d'].toString())),
      ]),
    );
  }
}
