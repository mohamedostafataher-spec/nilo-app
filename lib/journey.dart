import 'i18n.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'bottles.dart' show Sb;
import 'circles.dart' show niloJoined, niloJoinGate;
import 'screens.dart' show toast;

/// Levels come from xp (earned on the server). Names are ours, unlock rewards come later.
const kLevels = [
  ['Traveler', 'مسافر', 0],
  ['Explorer', 'مستكشف', 100],
  ['Ambassador', 'سفير', 300],
  ['Legend', 'أسطورة', 700],
];

int levelOf(int xp) {
  var l = 0;
  for (var i = 0; i < kLevels.length; i++) { if (xp >= (kLevels[i][2] as int)) l = i; }
  return l;
}

String flagOf(String cc) => cc.length == 2 ? String.fromCharCodes(cc.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65)) : '🌍';

/// Wide card on the home screen that opens the daily journey.
class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JourneyPage())),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [kGreen.withOpacity(0.35), Colors.black.withOpacity(0.3)]),
            borderRadius: BorderRadius.circular(16), border: Border.all(color: kGreen.withOpacity(0.6))),
          child: Row(children: [
            const Text('🧭', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L('Daily journey'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text(L('One new country every day. Collect a gift and a real fact.'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
            const Icon(Icons.chevron_right),
          ]),
        ),
      );
}

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  bool loading = true, joined = false, busy = false, failed = false;
  List<dynamic> stations = [];
  Map<String, dynamic> st = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; failed = false; });
    joined = await niloJoined();
    if (joined) {
      try {
        if (!await Sb.signIn()) throw Exception('auth');
        stations = (await Sb.get('journey_stations?select=idx,cc,city,country&order=idx') as List?) ?? [];
        st = Map<String, dynamic>.from(await Sb.rpc('journey_state') as Map);
      } catch (_) { failed = true; }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _claim() async {
    setState(() => busy = true);
    try {
      final r = Map<String, dynamic>.from(await Sb.rpc('journey_claim') as Map);
      st = r;
      if (mounted) toast(context, '${L('Collected')} +${r['reward']} 💎${(r['bonus'] ?? 0) > 0 ? ' (${L('7-day bonus')})' : ''}');
    } catch (_) {
      if (mounted) toast(context, L('You already collected today, or the connection failed.'));
      await _load();
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final ar = Ui.lang == 'ar';
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!joined) {
      body = niloJoinGate(context, _load);
    } else if (failed || st.isEmpty) {
      body = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(L('Could not load. Check your connection.')),
        const SizedBox(height: 10),
        FilledButton(onPressed: _load, child: Text(L('Try again'))),
      ]));
    } else {
      final xp = (st['xp'] ?? 0) as int, gems = (st['gems'] ?? 0) as int, streak = (st['streak'] ?? 0) as int;
      final claimed = st['claimed'] == true;
      final station = Map<String, dynamic>.from(st['station'] as Map);
      final cur = (station['idx'] ?? 0) as int;
      final lv = levelOf(xp);
      final next = lv + 1 < kLevels.length ? kLevels[lv + 1][2] as int : null;
      final fact = (ar ? station['fact_ar'] : station['fact']).toString();
      body = ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('💎 $gems'),
          _pill('🔥 $streak ${L('day streak')}'),
          _pill('⭐ ${ar ? kLevels[lv][1] : kLevels[lv][0]}'),
        ]),
        if (next != null) Padding(padding: const EdgeInsets.only(top: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: ((xp - (kLevels[lv][2] as int)) / (next - (kLevels[lv][2] as int))).clamp(0.0, 1.0), minHeight: 6, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 4),
          Text('$xp / $next XP → ${ar ? kLevels[lv + 1][1] : kLevels[lv + 1][0]}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: kGreen.withOpacity(0.5))),
          child: Column(children: [
            Text(flagOf((station['cc'] ?? '').toString()), style: const TextStyle(fontSize: 54)),
            const SizedBox(height: 6),
            Text('${station['city']}, ${station['country']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(claimed ? L('Today\'s stop') : L('Next stop'), style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            Text(claimed ? fact : L('Collect your gift to reveal today\'s fact.'), textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: (claimed || busy) ? null : _claim,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(claimed ? Icons.check : Icons.card_giftcard),
              label: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(claimed ? L('Come back tomorrow') : L('Collect gift'))),
            )),
          ]),
        ),
        const SizedBox(height: 18),
        Text(L('Your route'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final s in stations)
          Builder(builder: (_) {
            final i = (s['idx'] ?? 0) as int;
            final done = i < cur || (i == cur && claimed);
            final here = i == cur;
            return ListTile(
              dense: true,
              leading: Text(flagOf((s['cc'] ?? '').toString()), style: TextStyle(fontSize: 24, color: done || here ? null : Colors.white38)),
              title: Text('${s['city']}', style: TextStyle(fontWeight: here ? FontWeight.w900 : FontWeight.w500, color: done || here ? Colors.white : Colors.white54)),
              subtitle: Text('${s['country']}', style: const TextStyle(fontSize: 11)),
              trailing: Icon(done ? Icons.check_circle : (here ? Icons.place : Icons.lock_outline), color: done ? Colors.greenAccent : (here ? kGreen : Colors.white30), size: 20),
            );
          }),
        const SizedBox(height: 8),
        Text(L('Gems are stored on the server. Every stop is a real place with a real fact.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]);
    }
    return Scaffold(appBar: AppBar(title: Text(L('Daily journey')), backgroundColor: kBg), body: body);
  }
}
