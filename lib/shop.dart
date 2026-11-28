import 'i18n.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'bottles.dart' show Sb;
import 'circles.dart' show niloJoined, niloJoinGate;
import 'screens.dart' show toast;
import 'profile.dart' show AvatarView;
import 'journey.dart' show flagOf;

/// Gems shop and the daily riddle. All prices, balances and answers are checked on the server.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  bool loading = true, joined = false, failed = false, busy = false;
  int gems = 0, eyes = 0, triesLeft = 0;
  bool solved = false;
  String riddle = '';
  final ans = TextEditingController(), who = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ans.dispose();
    who.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { loading = true; failed = false; });
    joined = await niloJoined();
    if (joined) {
      try {
        if (!await Sb.signIn()) throw Exception('auth');
        final cs = Map<String, dynamic>.from(await Sb.rpc('card_state') as Map);
        gems = (cs['gems'] ?? 0) as int;
        final w = (await Sb.get('wallet?select=items') as List?) ?? [];
        eyes = w.isEmpty ? 0 : int.tryParse(((w.first['items'] ?? {}) as Map)['eye']?.toString() ?? '0') ?? 0;
        final r = Map<String, dynamic>.from(await Sb.rpc('riddle_state') as Map);
        riddle = (Ui.lang == 'ar' ? r['q_ar'] : r['q']).toString();
        solved = r['solved'] == true;
        triesLeft = (r['tries_left'] ?? 0) as int;
      } catch (_) { failed = true; }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _buy() async {
    setState(() => busy = true);
    try {
      final r = Map<String, dynamic>.from(await Sb.rpc('shop_buy', {'p_item': 'eye'}) as Map);
      gems = (r['gems'] ?? gems) as int;
      eyes = int.tryParse(((r['items'] ?? {}) as Map)['eye']?.toString() ?? '0') ?? eyes;
      if (mounted) toast(context, L('Watcher eye added.'));
    } catch (_) { if (mounted) toast(context, L('Not enough gems.')); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _answer() async {
    final t = ans.text.trim();
    if (t.isEmpty) return;
    setState(() => busy = true);
    try {
      final r = Map<String, dynamic>.from(await Sb.rpc('riddle_answer', {'p_text': t}) as Map);
      gems = (r['gems'] ?? gems) as int;
      triesLeft = (r['tries_left'] ?? 0) as int;
      if (r['correct'] == true) { solved = true; if (mounted) toast(context, '${L('Correct!')} +10 💎'); }
      else if (mounted) toast(context, L('Not quite. Try again.'));
    } catch (_) { if (mounted) toast(context, L('No more tries today.')); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _find() async {
    final n = who.text.trim();
    if (n.length < 2) return;
    setState(() => busy = true);
    List<dynamic> res = [];
    var ok = true;
    try {
      res = (await Sb.rpc('find_user', {'p_name': n}) as List?) ?? [];
      eyes = eyes > 0 ? eyes - 1 : 0;
    } catch (_) { ok = false; if (mounted) toast(context, L('You need a watcher eye.')); }
    if (mounted) setState(() => busy = false);
    if (!ok || !mounted) return;
    await showModalBottomSheet(context: context, backgroundColor: kBg, builder: (c) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(16),
      child: res.isEmpty
          ? Padding(padding: const EdgeInsets.all(12), child: Text(L('Nobody with exactly that name. The eye was used.'), textAlign: TextAlign.center))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              for (final u in res)
                ListTile(
                  leading: AvatarView(avatar: (u['avatar'] ?? '').toString(), path: (u['avatar_path'] ?? '').toString(), size: 44),
                  title: Text('${u['nick']}'),
                  subtitle: Text(flagOf((u['cc'] ?? '').toString())),
                  trailing: FilledButton(onPressed: () async {
                    String m;
                    try {
                      final r = (await Sb.rpc('request_friend_uid', {'p_uid': u['uid']})).toString();
                      m = r == 'accepted' ? L('You are now friends.') : (r == 'sent' ? L('Friend request sent.') : L('Could not send the request.'));
                    } catch (_) { m = L('Could not send the request. Check your connection.'); }
                    if (c.mounted) { Navigator.pop(c); toast(context, m); }
                  }, child: Text(L('Add friend'))),
                ),
            ]),
    )));
    if (mounted) setState(() {});
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!joined) {
      body = niloJoinGate(context, _load);
    } else if (failed) {
      body = Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(L('Could not load. Check your connection.')),
        const SizedBox(height: 10),
        FilledButton(onPressed: _load, child: Text(L('Try again'))),
      ]));
    } else {
      body = ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Text('💎 $gems', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
        const SizedBox(height: 14),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('👁️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(L('Watcher eye'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text('× $eyes', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(L('Find an adult Nilo user by their exact display name and send a friend request. One eye per search. People you blocked, or who blocked you, never show up.'), style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton(onPressed: busy ? null : _buy, child: Text('${L('Buy')} • 30 💎')),
          ]),
          if (eyes > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: who, maxLength: 20, decoration: InputDecoration(labelText: L('Exact display name'), border: const OutlineInputBorder(), counterText: ''))),
              const SizedBox(width: 8),
              FilledButton(onPressed: busy ? null : _find, child: Text(L('Search'))),
            ]),
          ],
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🧩', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(L('Daily riddle'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text(solved ? '✅' : '$triesLeft ${L('tries')}', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          Text(riddle, style: const TextStyle(height: 1.45, fontSize: 15)),
          const SizedBox(height: 10),
          if (solved) Text(L('Solved. A new riddle comes tomorrow.'), style: const TextStyle(color: Colors.greenAccent)) else if (triesLeft <= 0) Text(L('No more tries today.'), style: const TextStyle(color: Colors.white60)) else Row(children: [
            Expanded(child: TextField(controller: ans, maxLength: 40, decoration: InputDecoration(labelText: L('Your answer'), border: const OutlineInputBorder(), counterText: ''))),
            const SizedBox(width: 8),
            FilledButton(onPressed: busy ? null : _answer, child: Text(L('Answer'))),
          ]),
          const SizedBox(height: 4),
          Text(L('Right answer: +10 gems.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ])),
        Text(L('More powerups (compass, translator bird, torch) arrive once they work end to end.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]);
    }
    return Scaffold(appBar: AppBar(title: Text(L('Shop and riddle')), backgroundColor: kBg), body: body);
  }
}
