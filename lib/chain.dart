import 'health.dart';
import 'package:flutter/material.dart';
import 'bottles.dart';
import 'circles.dart' show niloJoined, niloJoinGate;
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;

String _fl(String code) {
  if (code.length != 2) return '🌍';
  final c = code.toUpperCase();
  return String.fromCharCodes([0x1F1E6 + c.codeUnitAt(0) - 65, 0x1F1E6 + c.codeUnitAt(1) - 65]);
}

/// Pass It On: a short story that travels through 6 strangers, one line each (max 160 characters).
/// You start one with a first line, or catch one waiting for the next line. After you add yours it moves on.
/// When it has 6 lines everybody who wrote a line can read the whole thing and see the flags of the writers.
/// 18+, no links or numbers (checked on the server), report any line, 3 new chains a day.
class PassItOnPage extends StatefulWidget {
  const PassItOnPage({super.key});
  @override
  State<PassItOnPage> createState() => _PassItOnPageState();
}

class _PassItOnPageState extends State<PassItOnPage> {
  bool busy = true, joined = false;
  List mine = [];
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    joined = await niloJoined();
    if (joined) {
      try { await Sb.signIn(); mine = (await Sb.rpc('my_chains') as List?) ?? []; } catch (e, st) { Health.log(e, st); }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _start() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least a few words'); return; }
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    try {
      final r = await Sb.rpc('start_chain', {'p_body': t});
      if (r == null) { if (mounted) toast(context, 'Could not start. Set up your 18+ profile first.'); } else { c.clear(); if (mounted) toast(context, 'Your story is on its way. • بدأت الحكاية'); }
    } catch (_) { if (mounted) toast(context, 'No links or numbers, max 3 new stories a day.'); }
    _load();
  }

  Future<void> _catch() async {
    try {
      final r = await Sb.rpc('catch_chain');
      if (r == null) { if (mounted) toast(context, 'No story is waiting right now. Try later, or start one.'); return; }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChainPage(id: r.toString(), canWrite: true)));
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(L('Pass it on • مرّرها')), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : !joined
                ? niloJoinGate(context, _load)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(L('A story with 6 lines written by 6 strangers. You add one line and pass it on.\nحكاية من ٦ سطور بيكتبها ٦ ناس غرب. تضيف سطر وتمرّرها.'), style: const TextStyle(height: 1.5)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _catch, icon: const Icon(Icons.download), label: Text(L('Catch a story • امسك حكاية'))),
                    const SizedBox(height: 12),
                    TextField(controller: c, maxLength: 160, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: L('First line of a new story • أول سطر'), border: const OutlineInputBorder())),
                    OutlinedButton(onPressed: _start, child: Text(L('Start a story • ابدأ حكاية'))),
                    const SizedBox(height: 16),
                    Text(L('My stories • حكاياتي'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (mine.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(L('Nothing yet.'), style: const TextStyle(color: Colors.white60))),
                    for (final m in mine)
                      Card(color: Colors.white10, child: ListTile(
                        title: Text((m['first_line'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(m['status'] == 'done' ? L('Finished • خلصت') : '${m['lines']}/6'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChainPage(id: m['id'].toString(), canWrite: false))),
                      )),
                  ]),
      );
}

class ChainPage extends StatefulWidget {
  final String id;
  final bool canWrite;
  const ChainPage({super.key, required this.id, required this.canWrite});
  @override
  State<ChainPage> createState() => _ChainPageState();
}

class _ChainPageState extends State<ChainPage> {
  List lines = [];
  bool busy = true;
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { lines = (await Sb.rpc('chain_view', {'p_chain': widget.id}) as List?) ?? []; } catch (e, st) { Health.log(e, st); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _add() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least a few words'); return; }
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    try {
      final ok = await Sb.rpc('add_chain_line', {'p_chain': widget.id, 'p_body': t});
      if (ok == true) { if (mounted) { toast(context, 'Passed on. • اتمرّرت'); Navigator.pop(context); } return; }
      if (mounted) toast(context, 'This story is no longer yours to continue.');
    } catch (_) { if (mounted) toast(context, 'No links or numbers, please.'); }
  }

  Future<void> _report(Map l) async {
    try { await Sb.rpc('report_chain_line', {'p_id': l['id']}); } catch (e, st) { Health.log(e, st); }
    if (mounted) toast(context, 'Reported. Thank you.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final mineWrote = lines.any((l) => l['mine'] == true);
    final write = widget.canWrite && !(lines.length >= 6) && !(mineWrote && lines.length > 1 && false);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Story • حكاية')), backgroundColor: kBg),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final l in lines)
                Card(color: l['mine'] == true ? const Color(0xFF1B5E4B) : const Color(0xFF12304D), child: ListTile(
                  leading: Text('${l['pos']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  title: Text(l['body'].toString()),
                  subtitle: Text(_fl((l['country'] ?? '').toString())),
                  trailing: l['mine'] == true ? null : IconButton(icon: const Icon(Icons.flag_outlined, size: 18), onPressed: () => _report(l as Map)),
                )),
              if (write) ...[
                const SizedBox(height: 8),
                TextField(controller: c, maxLength: 160, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: L('Your line • سطرك'), border: const OutlineInputBorder())),
                FilledButton(onPressed: _add, child: Text(L('Pass it on • مرّرها'))),
              ],
            ]),
    );
  }
}
