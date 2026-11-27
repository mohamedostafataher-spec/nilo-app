import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'bottles.dart';
import 'net.dart';
import 'circles.dart' show niloJoined, niloJoinGate;
import 'i18n.dart';
import 'main.dart';
import 'profile.dart' show AvatarView;
import 'screens.dart' show toast;

String _fl(String code) {
  if (code.length != 2) return '🌍';
  final c = code.toUpperCase();
  return String.fromCharCodes([0x1F1E6 + c.codeUnitAt(0) - 65, 0x1F1E6 + c.codeUnitAt(1) - 65]);
}

/// Friends: add by friend code (the same code as your invite code), both sides must accept.
/// Friends feed: the last 24 hours of stories from your accepted friends only, newest first, no ranking.
/// No contacts are read. Nothing is sent without a tap.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  bool busy = true, joined = false;
  String code = '';
  List friends = [];
  List feed = [];
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    joined = await niloJoined();
    if (joined) {
      try {
        await Sb.signIn();
        code = ((await Sb.rpc('my_invite_code')) ?? '').toString();
        friends = (await Sb.rpc('my_friends') as List?) ?? [];
        final ids = ((await Sb.rpc('friend_ids')) as List?)?.map((e) => e.toString()).toList() ?? [];
        if (ids.isNotEmpty) {
          final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
          feed = (await Sb.get('stories?select=id,author,nick,country,body,mood,created_at&author=in.(${ids.join(',')})&created_at=gte.$since&order=created_at.desc&limit=50') as List?) ?? [];
        } else { feed = []; }
      } catch (_) {}
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _add() async {
    final t = c.text.trim();
    if (t.isEmpty) return;
    try {
      final r = (await Sb.rpc('request_friend', {'p_code': t})).toString();
      final m = {
        'sent': 'Request sent. They need to accept. • اتبعت الطلب',
        'accepted': 'You are friends now. • بقيتوا أصحاب',
        'self': 'That is your own code.',
        'age': 'Set up your 18+ profile first (send or read a papyrus once).',
      }[r] ?? 'No one with that code.';
      if (mounted) toast(context, m);
      c.clear();
      _load();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  Future<void> _answer(String uid, bool ok) async {
    try { await Sb.rpc('respond_friend', {'p_uid': uid, 'p_accept': ok}); } catch (_) {}
    _load();
  }

  Future<void> _remove(String uid) async {
    try { await Sb.rpc('remove_friend', {'p_uid': uid}); } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final incoming = friends.where((f) => f['status'] == 'pending' && f['incoming'] == true).toList();
    final sent = friends.where((f) => f['status'] == 'pending' && f['incoming'] != true).toList();
    final ok = friends.where((f) => f['status'] == 'accepted').toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Friends • الأصحاب')), backgroundColor: kBg),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : !joined
              ? niloJoinGate(context, _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(L('Your friend code • كودك'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(code.isEmpty ? '...' : code, style: const TextStyle(fontSize: 26, letterSpacing: 3, fontWeight: FontWeight.w900)),
                      Row(children: [
                        TextButton.icon(onPressed: code.isEmpty ? null : () { Clipboard.setData(ClipboardData(text: code)); toast(context, 'اتنسخ'); }, icon: const Icon(Icons.copy, size: 16), label: Text(L('Copy'))),
                        TextButton.icon(onPressed: code.isEmpty ? null : () { Share.share('Nilo • https://nilo-dl.vercel.app/?c=$code  (my friend code: $code)'); }, icon: const Icon(Icons.share, size: 16), label: Text(L('Share'))),
                      ]),
                    ]))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: c, maxLength: 12, autocorrect: false, decoration: InputDecoration(counterText: '', hintText: L('Friend code • كود صاحبك'), border: const OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _add, child: Text(L('Add • أضف'))),
                    ]),
                    if (incoming.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(L('Requests • طلبات'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      for (final f in incoming) _row(f, [
                        IconButton(icon: const Icon(Icons.check_circle, color: Colors.greenAccent), onPressed: () => _answer(f['uid'].toString(), true)),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () => _answer(f['uid'].toString(), false)),
                      ]),
                    ],
                    if (sent.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(L('Waiting • في الانتظار'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      for (final f in sent) _row(f, [TextButton(onPressed: () => _remove(f['uid'].toString()), child: Text(L('Cancel')))]),
                    ],
                    const SizedBox(height: 14),
                    Text('${L('Friends • الأصحاب')} (${ok.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (ok.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(L('No friends yet. Share your code, or type a friend\'s code above.'), style: const TextStyle(color: Colors.white60))),
                    for (final f in ok) _row(f, [
                      IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DmPage(uid: f['uid'].toString(), nick: (f['nick'] ?? '').toString())))),
                      PopupMenuButton<String>(onSelected: (v) { if (v == 'rm') _remove(f['uid'].toString()); },
                        itemBuilder: (_) => [PopupMenuItem(value: 'rm', child: Text(L('Remove friend')))]),
                    ]),
                    const SizedBox(height: 18),
                    Text(L('Friends feed, last 24 hours • حكايات أصحابك'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (feed.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(L('Nothing yet. When your friends post a story it shows here, newest first.'), style: const TextStyle(color: Colors.white60))),
                    for (final s in feed)
                      Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_fl((s['country'] ?? '').toString())} ${s['nick'] ?? ''}  ${s['mood'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text((s['body'] ?? '').toString()),
                      ]))),
                    const SizedBox(height: 24),
                  ]),
                ),
    );
  }

  Widget _row(Map f, List<Widget> actions) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: AvatarView(avatar: (f['avatar'] ?? '').toString(), size: 40),
        title: Text('${_fl((f['cc'] ?? '').toString())} ${f['nick'] ?? ''}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
      );
}


/// Direct messages between accepted friends only. Text only, no links or phone numbers (checked on the server too),
/// 500 characters, 300 messages a day. Report the other person's message, delete your own, or remove the friend.
/// Messages refresh every 6 seconds while the page is open. Tap a message to translate it.
class DmPage extends StatefulWidget {
  final String uid, nick;
  const DmPage({super.key, required this.uid, required this.nick});
  @override
  State<DmPage> createState() => _DmPageState();
}

class _DmPageState extends State<DmPage> {
  List msgs = [];
  final c = TextEditingController();
  final tr = <String, String>{};
  Timer? t;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    t = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  @override
  void dispose() { t?.cancel(); c.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final me = Sb.uid;
      final o = widget.uid;
      final r = await Sb.get('dms?select=id,sender,recipient,body,created_at&or=(and(sender.eq.$me,recipient.eq.$o),and(sender.eq.$o,recipient.eq.$me))&order=created_at.desc&limit=100') as List;
      if (mounted) setState(() => msgs = r.reversed.toList());
    } catch (_) {}
  }

  Future<void> _send() async {
    final x = c.text.trim();
    if (x.isEmpty || sending) return;
    final b = niloBad(x);
    if (b.isNotEmpty) { toast(context, b); return; }
    setState(() => sending = true);
    try {
      final ok = await Sb.rpc('send_dm', {'p_uid': widget.uid, 'p_body': x});
      if (ok == true) { c.clear(); await _load(); } else if (mounted) { toast(context, 'Could not send. You must be friends, and not blocked.'); }
    } catch (_) { if (mounted) toast(context, 'No links or phone numbers, please. • من غير روابط أو أرقام'); }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _translate(String id, String text) async {
    final r = await trText(text, 'auto', Ui.lang == 'ar' ? 'ar' : 'en');
    if (!mounted) return;
    if (r.ok) { setState(() => tr[id] = r.translation); } else { toast(context, r.error.isEmpty ? 'Translation failed' : r.error); }
  }

  Future<void> _menu(Map m, bool mine) async {
    final v = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.translate), title: Text(L('Translate • ترجم')), onTap: () => Navigator.pop(context, 'tr')),
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: Text(L('Delete • احذف')), onTap: () => Navigator.pop(context, 'del')),
      if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: Text(L('Report • أبلغ')), onTap: () => Navigator.pop(context, 'rep')),
    ])));
    final id = m['id'].toString();
    if (v == 'tr') { _translate(id, m['body'].toString()); }
    if (v == 'del') { try { await Sb.delete('dms?id=eq.$id'); } catch (_) {} _load(); }
    if (v == 'rep') { try { await Sb.rpc('report_dm', {'p_id': id}); } catch (_) {} if (mounted) toast(context, 'Reported. Thank you.'); _load(); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(widget.nick.isEmpty ? L('Chat') : widget.nick), backgroundColor: kBg),
        body: Column(children: [
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Text(L('Say hello. • قول أهلا'), style: const TextStyle(color: Colors.white60)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i] as Map;
                      final mine = m['sender'] == Sb.uid;
                      final id = m['id'].toString();
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _menu(m, mine),
                          onTap: () => _menu(m, mine),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(color: mine ? const Color(0xFF1B5E4B) : const Color(0xFF12304D), borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m['body'].toString()),
                              if (tr[id] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr[id]!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                            ]),
                          ),
                        ),
                      );
                    }),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(children: [
                Expanded(child: TextField(controller: c, maxLength: 500, minLines: 1, maxLines: 4, decoration: InputDecoration(counterText: '', hintText: L('Message • رسالة'), border: const OutlineInputBorder()))),
                IconButton(icon: const Icon(Icons.send), onPressed: sending ? null : _send),
              ]),
            ),
          ),
        ]),
      );
}
