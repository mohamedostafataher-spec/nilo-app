import 'quests.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport;

/// Weekly challenge: one small real-life task per week, the same for everyone (rotates by week number).
/// Dish, song, riddle, phrase, look-around. Your answer stays on your phone; share it only if you tap Share.
/// Original text, no outside recipes or lyrics. The Recipe corner is the list of your own dish answers.
const List<List<String>> kChallenges = [
  ['🍲', 'dish', 'Cook or order one dish from a country that is not yours. Write its name and one thing you noticed.', 'اطبخ أو اطلب أكلة من بلد مش بلدك. اكتب اسمها وحاجة لاحظتها.'],
  ['🎵', 'song', 'Listen to one song in a language you do not speak. Write how it felt, not what it says.', 'اسمع أغنية بلغة مش بتتكلمها. اكتب حسّيت بإيه، مش بتقول إيه.'],
  ['🧩', 'riddle', 'Ask one person a riddle from your childhood. Write the riddle and what they answered.', 'اسأل حد لغز من أيام طفولتك. اكتب اللغز وهو جاوب إيه.'],
  ['🗣️', 'phrase', 'Learn how to say thank you in a new language and use it once today. Write the phrase.', 'اتعلم تقول شكراً بلغة جديدة وقولها مرة النهارده. اكتب العبارة.'],
  ['👀', 'look', 'Find one object at home that was made in another country. Write what and where.', 'دوّر على حاجة في بيتك مصنوعة في بلد تانية. اكتب إيه وفين.'],
  ['🍵', 'dish', 'Make a hot or cold drink from your family\'s habit. Write what is in it and who taught you.', 'اعمل مشروب على عادة عيلتك. اكتب فيه إيه ومين علّمك.'],
  ['📖', 'phrase', 'Teach one proverb from your culture to a friend. Write it in your language and your own translation.', 'علّم صاحبك مثل من ثقافتك. اكتبه بلغتك وبترجمتك.'],
  ['🌦️', 'look', 'Write one sentence about today\'s weather you would send to a stranger far away.', 'اكتب جملة عن طقس النهارده تبعتها لغريب بعيد.'],
  ['🥖', 'dish', 'Share the story of a bread or sweet people make where you live. Write it in two lines.', 'احكي عن عيش أو حلو بيتعمل عندك. اكتب في سطرين.'],
  ['🎶', 'song', 'Pick a lullaby or a tune you know from childhood. Write one memory it brings back.', 'اختار تهويدة أو لحن تعرفه من صغرك. اكتب ذكرى بيرجعها.'],
  ['🧭', 'riddle', 'Write your own riddle about a place in your city. Others can try it in a papyrus.', 'اكتب لغز من عندك عن مكان في مدينتك. تبعته في بردية.'],
  ['🤝', 'phrase', 'Write how people greet each other where you are, and one thing a visitor should not do.', 'اكتب الناس بتسلّم إزاي عندك، وحاجة الزائر ميعملهاش.'],
];

int _week() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ (86400000 * 7);

class WeeklyChallengePage extends StatefulWidget {
  const WeeklyChallengePage({super.key});
  @override
  State<WeeklyChallengePage> createState() => _WeeklyChallengePageState();
}

class _WeeklyChallengePageState extends State<WeeklyChallengePage> {
  final c = TextEditingController();
  Map<String, dynamic> done = {};

  List<String> get ch => kChallenges[_week() % kChallenges.length];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try { done = Map<String, dynamic>.from(jsonDecode(p.getString('weekly_done') ?? '{}')); } catch (_) {}
    final mine = done['${_week()}'];
    if (mine != null) c.text = (mine['t'] ?? '').toString();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least a few words'); return; }
    final first = done['${_week()}'] == null;
    done['${_week()}'] = {'t': t, 'k': ch[1], 'e': ch[0], 'q': ch[2]};
    final p = await SharedPreferences.getInstance();
    await p.setString('weekly_done', jsonEncode(done));
    Quests.mark('challenge');
    if (first) Passport.addReeds(5);
    if (mounted) { toast(context, first ? 'Saved. +5 Reeds. • اتحفظت' : 'Saved. • اتحفظت'); setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Ui.rtl;
    final dishes = done.entries.where((e) => e.value['k'] == 'dish').toList()..sort((a, b) => b.key.compareTo(a.key));
    final kept = done.length;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Weekly challenge • تحدي الأسبوع')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(color: const Color(0xFF12304D), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ch[0], style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(isAr ? ch[3] : ch[2], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 4),
          Text(isAr ? ch[2] : ch[3], style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]))),
        const SizedBox(height: 12),
        TextField(controller: c, maxLength: 240, minLines: 2, maxLines: 5, decoration: InputDecoration(hintText: L('Your answer, saved on your phone • إجابتك'), border: const OutlineInputBorder())),
        Row(children: [
          Expanded(child: FilledButton(onPressed: _save, child: Text(L('Save • احفظ')))),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () { final t = c.text.trim(); if (t.isEmpty) return; Share.share('${ch[0]} ${ch[2]}\n$t\n\nNilo • https://nilo-dl.vercel.app'); }, icon: const Icon(Icons.share, size: 16), label: Text(L('Share'))),
        ]),
        const SizedBox(height: 6),
        Text(L('Nothing is sent anywhere. Share only opens your phone\'s share sheet.'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 18),
        Text('${L('Done so far • خلصت')}: $kept', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(L('Recipe corner • ركن الأكلات'), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(L('Your own dish answers from dish weeks. Not copied from anywhere.'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (dishes.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(L('Nothing yet. Dish weeks will fill this list.'), style: const TextStyle(color: Colors.white60))),
        for (final d in dishes)
          Card(color: Colors.white10, child: ListTile(title: Text('${d.value['e'] ?? '🍲'} ${d.value['t']}'), subtitle: Text(d.value['q'].toString(), style: const TextStyle(fontSize: 11, color: Colors.white54)),
            trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: d.value['t'].toString())); toast(context, 'اتنسخ'); }))),
      ]),
    );
  }
}
