import 'health.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'bottles.dart';
import 'dmmedia.dart';
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
      } catch (e, st) { Health.log(e, st); }
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
    try { await Sb.rpc('respond_friend', {'p_uid': uid, 'p_accept': ok}); } catch (_) { if (mounted) toast(context, L('Could not do that. Check your connection.')); }
    _load();
  }

  Future<void> _remove(String uid) async {
    try { await Sb.rpc('remove_friend', {'p_uid': uid}); } catch (_) { if (mounted) toast(context, L('Could not do that. Check your connection.')); }
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
                        TextButton.icon(onPressed: code.isEmpty ? null : () { Share.share('Nilo • https://mohamedostafataher-spec.github.io/nilo-dl/?c=$code  (my friend code: $code)'); }, icon: const Icon(Icons.share, size: 16), label: Text(L('Share'))),
                      ]),
                    ]))),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupsPage())), icon: const Icon(Icons.groups), label: Text(L('Small groups (up to 12) • مجموعات'))),
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
  Timer? t, ts;
  bool sending = false;
  Map st = {};
  bool myReceipts = true;
  DateTime _typedAt = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _load();
    _status();
    Sb.rpc('my_chat_privacy', {}).then((v) { if (v is Map && mounted) setState(() => myReceipts = v['receipts'] != false); }).catchError((_) {});
    t = Timer.periodic(const Duration(seconds: 5), (_) => _load());
    ts = Timer.periodic(const Duration(seconds: 3), (_) => _status());
    c.addListener(_onType);
  }

  @override
  void dispose() { t?.cancel(); ts?.cancel(); c.removeListener(_onType); c.dispose(); super.dispose(); }

  /// Tells the other person's chat that I am typing (at most once every 3 seconds).
  void _onType() {
    if (c.text.isEmpty || DateTime.now().difference(_typedAt).inSeconds < 3) return;
    _typedAt = DateTime.now();
    Sb.rpc('dm_typing', {'p_peer': widget.uid}).catchError((_) {});
  }

  Future<void> _status() async {
    try {
      final v = await Sb.rpc('dm_status', {'p_peer': widget.uid});
      if (v is Map && mounted) setState(() => st = v);
    } catch (e, st2) { Health.log(e, st2); }
  }

  String _statusLine() {
    if (st['typing'] == true) return L('typing… • بيكتب…');
    if (st['online'] == true) return L('online • متصل');
    final sec = st['seen_s'];
    if (sec is num) {
      final m = sec ~/ 60;
      if (m < 60) return L('last seen $m min ago • اخر ظهور من $m د');
      if (m < 1440) return L('last seen ${m ~/ 60} h ago • اخر ظهور من ${m ~/ 60} ساعة');
      return L('last seen ${m ~/ 1440} d ago • اخر ظهور من ${m ~/ 1440} يوم');
    }
    return '';
  }

  Future<void> _privacy() async {
    var on = true, rc = myReceipts;
    try { final v = await Sb.rpc('my_chat_privacy', {}); if (v is Map) { on = v['online'] != false; rc = v['receipts'] != false; } } catch (e, st2) { Health.log(e, st2); }
    if (!mounted) return;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(L('Chat privacy • خصوصية الشات')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(value: on, onChanged: (v) => set(() => on = v), title: Text(L('Show when I am online • اظهر إني متصل'))),
        SwitchListTile(value: rc, onChanged: (v) => set(() => rc = v), title: Text(L('Read receipts (blue ticks) • علامة القراءة'))),
        Text(L('Like WhatsApp: if you turn these off, you also cannot see them for others. Typing is always shown to your friends in an open chat.'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ]),
      actions: [TextButton(onPressed: () async { try { await Sb.rpc('set_chat_privacy', {'p_online': on, 'p_receipts': rc}); } catch (e, st2) { Health.log(e, st2); } if (mounted) setState(() => myReceipts = rc); if (ctx.mounted) Navigator.pop(ctx); _status(); }, child: Text(L('Save • حفظ')))],
    )));
  }

  String _hm(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// WhatsApp-style ticks: one grey = sent, two grey = delivered, two blue = read (only when both people allow read receipts).
  Widget _ticks(Map m) {
    final read = m['read_at'] != null && myReceipts && st['receipts'] != false;
    final deliv = m['delivered_at'] != null || m['read_at'] != null;
    return Icon(deliv ? Icons.done_all : Icons.done, size: 15, color: read ? const Color(0xFF53BDEB) : Colors.white54);
  }

  Future<void> _load() async {
    try {
      final me = Sb.uid;
      final o = widget.uid;
      final r = await Sb.get('dms?select=id,sender,recipient,body,kind,media_path,created_at,delivered_at,read_at&or=(and(sender.eq.$me,recipient.eq.$o),and(sender.eq.$o,recipient.eq.$me))&order=created_at.desc&limit=100') as List;
      if (mounted) setState(() => msgs = r.reversed.toList());
      if (r.any((m) => (m as Map)['sender'] == widget.uid && (m['read_at'] == null || m['delivered_at'] == null))) { Sb.rpc('dm_open', {'p_peer': widget.uid}).catchError((_) {}); }
    } catch (e, st) { Health.log(e, st); }
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
    } catch (_) { if (mounted) toast(context, 'Could not send. Check your connection and try again.'); }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _photo() async {
    setState(() => sending = true);
    final err = await DmMedia.pickAndSendPhoto(widget.uid);
    if (!mounted) return;
    setState(() => sending = false);
    if (err != null) { toast(context, err); } else { _load(); }
  }

  Future<void> _translate(String id, String text) async {
    final r = await trText(text, 'auto', Ui.lang == 'ar' ? 'ar' : 'en');
    if (!mounted) return;
    if (r.ok) { setState(() => tr[id] = r.translation); } else { toast(context, r.error.isEmpty ? 'Translation failed' : r.error); }
  }

  Future<void> _menu(Map m, bool mine) async {
    final v = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if ((m['kind'] ?? 'text') == 'text') ListTile(leading: const Icon(Icons.translate), title: Text(L('Translate • ترجم')), onTap: () => Navigator.pop(context, 'tr')),
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: Text(L('Delete • احذف')), onTap: () => Navigator.pop(context, 'del')),
      if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: Text(L('Report • أبلغ')), onTap: () => Navigator.pop(context, 'rep')),
    ])));
    final id = m['id'].toString();
    if (v == 'tr') { _translate(id, m['body'].toString()); }
    if (v == 'del') { try { await Sb.delete('dms?id=eq.$id'); } catch (e, st) { Health.log(e, st); } _load(); }
    if (v == 'rep') { try { await Sb.rpc('report_dm', {'p_id': id}); } catch (e, st) { Health.log(e, st); } if (mounted) toast(context, 'Reported. Thank you.'); _load(); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, titleSpacing: 0,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.nick.isEmpty ? L('Chat') : widget.nick, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_statusLine().isNotEmpty) Text(_statusLine(), style: TextStyle(fontSize: 12, color: st['typing'] == true || st['online'] == true ? kGreen : Colors.white60)),
          ]),
          actions: [IconButton(icon: const Icon(Icons.lock_outline), tooltip: L('Chat privacy'), onPressed: _privacy)],
        ),
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
                              if ((m['kind'] ?? 'text') == 'text') Text(m['body'].toString()) else DmMediaBubble(kind: m['kind'].toString(), path: (m['media_path'] ?? '').toString()),
                              if (tr[id] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr[id]!, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                              Padding(padding: const EdgeInsets.only(top: 3), child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                                Text(_hm(m['created_at']?.toString()), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                if (mine) ...[const SizedBox(width: 4), _ticks(m)],
                              ])),
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
                IconButton(icon: const Icon(Icons.photo_outlined), tooltip: L('Photo • صورة'), onPressed: sending ? null : _photo),
                DmVoiceButton(toUid: widget.uid, onSent: _load),
                IconButton(icon: const Icon(Icons.send), onPressed: sending ? null : _send),
              ]),
            ),
          ),
        ]),
      );
}


/// Small groups: up to 12 people, joined only with the group's invite code. Same safety as DMs.
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  List groups = [];
  bool busy = true;
  final name = TextEditingController(), code = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { await Sb.signIn(); groups = (await Sb.rpc('my_groups') as List?) ?? []; } catch (e, st) { Health.log(e, st); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _create() async {
    final t = name.text.trim();
    if (t.length < 2) return;
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    try {
      final r = (await Sb.rpc('create_group', {'p_name': t})).toString();
      if (r.isEmpty) { if (mounted) toast(context, 'Could not create the group.'); } else { name.clear(); if (mounted) toast(context, 'Created. Share its code with friends. • اتعملت'); }
    } catch (_) { if (mounted) toast(context, 'Could not create the group (max 5, no links or numbers).'); }
    _load();
  }

  Future<void> _createEvent() async {
    final t = name.text.trim();
    if (t.length < 2) { toast(context, 'Write the event name first (for example: Match night).'); return; }
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
    if (tm == null) return;
    final at = DateTime(d.year, d.month, d.day, tm.hour, tm.minute).toUtc().toIso8601String();
    try {
      final r = (await Sb.rpc('create_event_room', {'p_name': t, 'p_at': at})).toString();
      if (r.isEmpty) { if (mounted) toast(context, 'Could not create the room.'); } else { name.clear(); if (mounted) toast(context, 'Event room created. Share its code. • اتعملت'); }
    } catch (_) { if (mounted) toast(context, 'Could not create (max 5 rooms, no links or numbers).'); }
    _load();
  }

  Future<void> _join() async {
    final t = code.text.trim();
    if (t.isEmpty) return;
    try {
      final r = (await Sb.rpc('join_group', {'p_code': t})).toString();
      final m = {'ok': 'Joined. • اتضمّيت', 'full': 'That group is full (12).', 'age': 'Set up your 18+ profile first.'}[r] ?? 'No group with that code.';
      if (mounted) toast(context, m);
      if (r == 'ok') code.clear();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(L('Groups • المجموعات')), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: TextField(controller: name, maxLength: 40, decoration: InputDecoration(counterText: '', hintText: L('New group name • اسم المجموعة'), border: const OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _create, child: Text(L('Create'))),
                ]),
                Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: _createEvent, icon: const Icon(Icons.event, size: 18), label: Text(L('Event room with a date • غرفة حدث')))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: code, maxLength: 8, autocorrect: false, decoration: InputDecoration(counterText: '', hintText: L('Group code • كود المجموعة'), border: const OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _join, child: Text(L('Join'))),
                ]),
                const SizedBox(height: 14),
                if (groups.isEmpty) Text(L('No groups yet.'), style: const TextStyle(color: Colors.white60)),
                for (final g in groups)
                  Card(color: Colors.white10, child: ListTile(
                    title: Text('${g['event_at'] != null ? '📅 ' : ''}${g['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${g['members']}/12  •  ${L('code')}: ${g['code']}${g['event_at'] != null ? '  •  ${DateTime.parse(g['event_at'].toString()).toLocal().toString().substring(0, 16)}' : ''}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share('Nilo group "${g['name']}" • code: ${g['code']} • https://mohamedostafataher-spec.github.io/nilo-dl')),
                      const Icon(Icons.chevron_right),
                    ]),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupChatPage(id: g['id'].toString(), title: g['name'].toString()))).then((_) => _load()),
                  )),
              ]),
      );
}

class GroupChatPage extends StatefulWidget {
  final String id, title;
  const GroupChatPage({super.key, required this.id, required this.title});
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  List msgs = [];
  final c = TextEditingController();
  final tr = <String, String>{};
  Timer? t;
  bool sending = false;

  @override
  void initState() { super.initState(); _load(); t = Timer.periodic(const Duration(seconds: 6), (_) => _load()); }

  @override
  void dispose() { t?.cancel(); c.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await Sb.get('chat_msgs?select=id,sender,nick,body,created_at&grp=eq.${widget.id}&order=created_at.desc&limit=100') as List;
      if (mounted) setState(() => msgs = r.reversed.toList());
    } catch (e, st) { Health.log(e, st); }
  }

  Future<void> _send() async {
    final x = c.text.trim();
    if (x.isEmpty || sending) return;
    final b = niloBad(x);
    if (b.isNotEmpty) { toast(context, b); return; }
    setState(() => sending = true);
    try {
      final ok = await Sb.rpc('send_group_msg', {'p_grp': widget.id, 'p_body': x});
      if (ok == true) { c.clear(); await _load(); } else if (mounted) { toast(context, 'Could not send.'); }
    } catch (_) { if (mounted) toast(context, 'No links or phone numbers, please. • من غير روابط أو أرقام'); }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _menu(Map m, bool mine) async {
    final v = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.translate), title: Text(L('Translate • ترجم')), onTap: () => Navigator.pop(context, 'tr')),
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: Text(L('Delete • احذف')), onTap: () => Navigator.pop(context, 'del')),
      if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: Text(L('Report • أبلغ')), onTap: () => Navigator.pop(context, 'rep')),
      if (!mine) ListTile(leading: const Icon(Icons.block), title: Text(L('Block • احظر')), onTap: () => Navigator.pop(context, 'blk')),
    ])));
    final id = m['id'].toString();
    if (v == 'tr') {
      final r = await trText(m['body'].toString(), 'auto', Ui.lang == 'ar' ? 'ar' : 'en');
      if (mounted && r.ok) setState(() => tr[id] = r.translation);
    }
    if (v == 'del') { try { await Sb.delete('chat_msgs?id=eq.$id'); } catch (e, st) { Health.log(e, st); } _load(); }
    if (v == 'rep') { try { await Sb.rpc('report_group_msg', {'p_id': id}); } catch (e, st) { Health.log(e, st); } if (mounted) toast(context, 'Reported. Thank you.'); _load(); }
    if (v == 'blk') { try { await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': m['sender']}); } catch (e, st) { Health.log(e, st); } if (mounted) toast(context, 'Blocked.'); }
  }

  Future<void> _leave() async {
    try { await Sb.rpc('leave_group', {'p_grp': widget.id}); } catch (e, st) { Health.log(e, st); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(widget.title), backgroundColor: kBg, actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), tooltip: L('Leave group'), onPressed: _leave),
        ]),
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
                          onTap: () => _menu(m, mine),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(color: mine ? const Color(0xFF1B5E4B) : const Color(0xFF12304D), borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (!mine) Text((m['nick'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w700)),
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
