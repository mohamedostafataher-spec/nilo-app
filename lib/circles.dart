import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'world.dart';
import 'bottles.dart';
import 'screens.dart' show toast;
import 'extras.dart' show niloRoute;

Future<bool> niloJoined() async {
  final p = await SharedPreferences.getInstance();
  return (p.getBool('b_age') ?? false) && (p.getString('b_nick') ?? '').isNotEmpty;
}

Widget niloJoinGate(BuildContext context, VoidCallback after) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('🧭'), style: TextStyle(fontSize: 54)),
          const SizedBox(height: 10),
          Text(L('For travelers 18 and older.\nJoin once to take part. • للمسافرين ١٨ سنة وأكتر'), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: () async { await Navigator.of(context).push(niloRoute(BottlesPage())); after(); }, child: Text(L('Join • انضم'))),
        ]),
      ),
    );

String _flagOf(String code) {
  for (final w in kWorld) { if (w[0] == code) return w[3] as String; }
  return '🌍';
}

String _agoText(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final m = DateTime.now().toUtc().difference(d.toUtc()).inMinutes;
  if (m < 1) return 'now';
  if (m < 60) return '${m}m';
  if (m < 1440) return '${m ~/ 60}h';
  return '${m ~/ 1440}d';
}

/// Travelers' circles: one public board per destination country, text only, 18+, report and block.
class CirclesPage extends StatefulWidget {
  const CirclesPage({super.key});
  @override
  State<CirclesPage> createState() => _CirclesPageState();
}

class _CirclesPageState extends State<CirclesPage> {
  bool joined = false, busy = true;
  String dest = '';
  List<dynamic> posts = [];
  String err = '';
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    dest = p.getString('circle_dest') ?? (Passport.country.isEmpty ? 'EG' : Passport.country);
    joined = await niloJoined();
    if (joined) { await _load(); } else if (mounted) { setState(() => busy = false); }
  }

  Future<void> _load() async {
    setState(() { busy = true; err = ''; });
    try {
      if (!await Sb.signIn()) throw Exception('offline');
      posts = await Sb.get('circle_posts?select=*&circle=eq.$dest&order=created_at.desc&limit=50') as List;
    } catch (_) { err = 'Could not load. Check your connection.'; }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _pick() async {
    final code = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E2A45), isScrollControlled: true, builder: (_) => SafeArea(child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: ListView(children: [
      Padding(padding: EdgeInsets.all(16), child: Text(L('Choose a destination • اختار وجهة'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
      for (final w in kWorld) ListTile(leading: Text(w[3] as String, style: const TextStyle(fontSize: 26)), title: Text('${w[1]} • ${w[2]}'), onTap: () => Navigator.pop(context, w[0] as String)),
    ]))));
    if (code == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('circle_dest', code);
    dest = code;
    _load();
  }

  Future<void> _post() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least 3 letters.'); return; }
    final p = await SharedPreferences.getInstance();
    try {
      await Sb.post('circle_posts', {'circle': dest, 'author': Sb.uid, 'nick': p.getString('b_nick') ?? 'Traveler', 'country': Passport.country, 'body': t});
      c.clear();
      FocusScope.of(context).unfocus();
      _load();
    } catch (e) {
      if (mounted) toast(context, e.toString().contains('limit') ? 'Daily limit reached (10 posts).' : 'Not sent. No links, emails or phone numbers please.');
    }
  }

  Future<void> _menu(Map s) async {
    final mine = s['author'] == Sb.uid;
    final v = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E2A45), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (mine) ListTile(leading: Icon(Icons.delete_outline), title: Text(L('Delete')), onTap: () => Navigator.pop(context, 'del'))
      else ...[
        ListTile(leading: Icon(Icons.flag_outlined), title: Text(L('Report')), onTap: () => Navigator.pop(context, 'rep')),
        ListTile(leading: Icon(Icons.block), title: Text(L('Block this person')), onTap: () => Navigator.pop(context, 'blk')),
      ],
    ])));
    if (v == null) return;
    try {
      if (v == 'del') await Sb.delete('circle_posts?id=eq.${s['id']}');
      if (v == 'rep') { await Sb.rpc('report_circle_post', {'pid': s['id']}); if (mounted) toast(context, 'Reported. Thank you.'); }
      if (v == 'blk') { await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': s['author']}); if (mounted) toast(context, 'Blocked.'); }
      _load();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  @override
  Widget build(BuildContext context) {
    final w = countryOf(dest);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: GestureDetector(onTap: _pick, child: Text('${w[3]} ${w[1]} circle • دايرة ${w[2]}  ▾')),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: !joined
          ? (busy ? const Center(child: CircularProgressIndicator()) : niloJoinGate(context, _init))
          : Column(children: [
              Expanded(
                child: busy
                    ? const Center(child: CircularProgressIndicator())
                    : err.isNotEmpty
                        ? Center(child: Text(L(err)))
                        : posts.isEmpty
                            ? Center(child: Padding(padding: EdgeInsets.all(24), child: Text(L('Nobody has written here yet.\nAsk a question or share a tip for this destination.\nمحدش كتب هنا لسه. اسأل أو شارك نصيحة.'), textAlign: TextAlign.center, style: TextStyle(height: 1.5))))
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: posts.length,
                                itemBuilder: (_, i) {
                                  final s = Map<String, dynamic>.from(posts[i] as Map);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(16)),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text('${_flagOf((s['country'] ?? '').toString())} ${s['nick']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(width: 8),
                                        Text(_agoText((s['created_at'] ?? '').toString()), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                        const Spacer(),
                                        InkWell(onTap: () => _menu(s), child: const Icon(Icons.more_vert, color: Colors.white54, size: 20)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text((s['body'] ?? '').toString(), style: const TextStyle(height: 1.4, fontSize: 15)),
                                    ]),
                                  );
                                },
                              ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(children: [
                    Expanded(child: TextField(controller: c, maxLength: 300, maxLines: 2, minLines: 1, decoration: InputDecoration(counterText: '', hintText: L('Ask or share a tip • اسأل أو شارك'), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20)), borderSide: BorderSide.none)))),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _post, icon: const Icon(Icons.send)),
                  ]),
                ),
              ),
              Padding(padding: EdgeInsets.only(bottom: 4), child: Text(L('18+. No links, emails or phone numbers. Meet only in public places.'), style: TextStyle(fontSize: 10, color: Colors.white38))),
            ]),
    );
  }
}
