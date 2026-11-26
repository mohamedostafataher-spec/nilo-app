import 'i18n.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'world.dart' show Passport, kWorld;

/// Moon phase computed on the phone from the date (no network).
class MoonInfo {
  final double phase; // 0..1, 0 = new moon
  MoonInfo(this.phase);
  factory MoonInfo.now() {
    final days = DateTime.now().toUtc().difference(DateTime.utc(2000, 1, 6, 18, 14)).inSeconds / 86400.0;
    final p = (days / 29.530588853) % 1.0;
    return MoonInfo(p < 0 ? p + 1 : p);
  }
  int get illumination => ((1 - math.cos(2 * math.pi * phase)) / 2 * 100).round();
  String get icon {
    final i = (phase * 8).round() % 8;
    return const ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'][i];
  }
  String get name {
    final i = (phase * 8).round() % 8;
    return const ['New moon • محاق', 'Waxing crescent • هلال متزايد', 'First quarter • تربيع أول', 'Waxing gibbous • أحدب متزايد', 'Full moon • بدر', 'Waning gibbous • أحدب متناقص', 'Last quarter • تربيع أخير', 'Waning crescent • هلال متناقص'][i];
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<Map> hol = [];
  List<String> events = [];
  bool holDone = false, evDone = false, holErr = false, evErr = false;
  late String cc = Passport.country.isEmpty ? 'EG' : Passport.country;

  @override
  void initState() { super.initState(); _hol(); _events(); }

  Future<void> _hol() async {
    setState(() { holDone = false; holErr = false; });
    try {
      final r = await http.get(Uri.parse('https://date.nager.at/api/v3/NextPublicHolidays/$cc')).timeout(const Duration(seconds: 12));
      final l = jsonDecode(r.body) as List;
      hol = l.take(5).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { holErr = true; }
    if (mounted) setState(() => holDone = true);
  }

  Future<void> _events() async {
    try {
      final n = DateTime.now();
      final mm = n.month.toString().padLeft(2, '0'), dd = n.day.toString().padLeft(2, '0');
      final r = await http.get(Uri.parse('https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/events/$mm/$dd'), headers: {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 12));
      final l = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['events'] as List;
      final out = <String>[];
      for (final e in l) {
        final m = e as Map;
        out.add('${m['year']}: ${m['text']}');
      }
      out.shuffle(math.Random(n.year * 1000 + n.month * 40 + n.day));
      events = out.take(5).toList();
    } catch (_) { evErr = true; }
    if (mounted) setState(() => evDone = true);
  }

  Widget _card(String title, List<Widget> kids) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2A4F74))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(L(title), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 8), ...kids]),
      );

  @override
  Widget build(BuildContext context) {
    final moon = MoonInfo.now();
    final flag = kWorld.where((w) => w[0] == cc).map((w) => w[3] as String).firstOrNull ?? '🌍';
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Today in the world • النهارده')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _card('Moon • القمر', [
          Row(children: [Text(moon.icon, style: TextStyle(fontSize: 44)), SizedBox(width: 12), Expanded(child: Text(Ui.rtl ? '${moon.name}\nمضيء ${moon.illumination}%' : '${moon.name}\n${moon.illumination}% lit', style: TextStyle(height: 1.4)))]),
          Text(L('Calculated on your phone from today\'s date.'), style: TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        _card('$flag Public holidays • الإجازات', [
          if (!holDone) const LinearProgressIndicator()
          else if (holErr) Text(L('Could not load. Check your connection.'))
          else if (hol.isEmpty) Text(L('The free holiday source has no data for this country.'))
          else for (final h in hol) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${h['date']}  •  ${h['localName'] == h['name'] ? h['name'] : '${h['name']} (${h['localName']})'}')),
          Text(L('Source: Nager.Date. Dates of moon-based holidays can differ by a day locally.'), style: TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        _card('On this day • في مثل النهارده', [
          if (!evDone) const LinearProgressIndicator()
          else if (evErr || events.isEmpty) Text(L('Could not load. Check your connection.'))
          else for (final e in events) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(e, style: const TextStyle(height: 1.35))),
          Text(L('Source: Wikipedia (English). Text is not translated.'), style: TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
      ]),
    );
  }
}
