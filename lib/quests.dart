import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'world.dart' show Passport;

/// Daily quests: 3 small things a day taken from a pool of 6, all real actions inside the app.
/// An action is only counted when the app really did it (answer posted, country opened, palm grown...).
/// Finish all 3 and you get 5 Reeds, once a day.
class Quests {
  static const pool = <List<String>>[
    ['question', '❓', 'Answer the question of the day', 'جاوب سؤال اليوم'],
    ['globe', '🌐', 'Open a country on the Globe', 'افتح بلد على الكورة'],
    ['challenge', '🗓️', 'Save this week\'s challenge answer', 'احفظ إجابة تحدي الأسبوع'],
    ['focus', '🌴', 'Finish one focus session', 'خلّص جلسة تركيز'],
    ['mood', '🌤️', 'Save today\'s mood sky', 'احفظ سما المزاج'],
    ['word', '📖', 'Save a word to your word book', 'احفظ كلمة في كتاب كلماتك'],
  ];

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
  static int _dayNum() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

  static List<List<String>> today() {
    final d = _dayNum();
    return [for (var i = 0; i < 3; i++) pool[(d * 2 + i * 2 + (i == 2 ? 1 : 0)) % pool.length]].toSet().toList();
  }

  static Future<Set<String>> done() async {
    final p = await SharedPreferences.getInstance();
    try {
      final m = jsonDecode(p.getString('quests') ?? '{}') as Map;
      if (m['d'] != _today()) return {};
      return Set<String>.from(m['done'] as List);
    } catch (_) { return {}; }
  }

  static Future<void> mark(String id) async {
    final p = await SharedPreferences.getInstance();
    final d = await done();
    if (d.contains(id)) return;
    d.add(id);
    await p.setString('quests', jsonEncode({'d': _today(), 'done': d.toList()}));
    final ids = today().map((e) => e[0]).toSet();
    if (ids.isNotEmpty && ids.every(d.contains) && p.getString('quests_paid') != _today()) {
      await p.setString('quests_paid', _today());
      Passport.addReeds(5);
    }
  }
}

class QuestsCard extends StatefulWidget {
  const QuestsCard({super.key});
  @override
  State<QuestsCard> createState() => _QuestsCardState();
}

class _QuestsCardState extends State<QuestsCard> {
  Set<String> d = {};
  @override
  void initState() { super.initState(); Quests.done().then((v) { if (mounted) setState(() => d = v); }); }

  @override
  Widget build(BuildContext context) {
    final t = Quests.today();
    final all = t.every((q) => d.contains(q[0]));
    return Card(color: const Color(0xFF12304D), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${L('Today\'s quests • مهام النهارده')}  ${all ? '🎉 +5 🌿' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
      for (final q in t)
        ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Text(q[1], style: const TextStyle(fontSize: 22)), title: Text(Ui.rtl ? q[3] : q[2]),
          trailing: Icon(d.contains(q[0]) ? Icons.check_circle : Icons.radio_button_unchecked, color: d.contains(q[0]) ? Colors.greenAccent : Colors.white38)),
      Text(L('Finish all three for 5 Reeds.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
    ])));
  }
}
