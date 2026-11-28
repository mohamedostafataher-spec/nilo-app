import 'health.dart';
import 'package:flutter/material.dart';
import 'bottles.dart';
import 'circles.dart' show niloJoined, niloJoinGate;
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport, kWorld;

/// Local Tip Board: short tips about a country written by people who live there or visited. 18+, no links or numbers,
/// no phone numbers, no addresses, 5 tips a day. Report or delete. Shown in the Play hub only when there are at least 10 real members.
class TipBoardPage extends StatefulWidget {
  const TipBoardPage({super.key});
  @override
  State<TipBoardPage> createState() => _TipBoardPageState();
}

class _TipBoardPageState extends State<TipBoardPage> {
  bool joined = false, busy = true;
  String cc = '';
  List rows = [];
  final c = TextEditingController();

  @override
  void initState() { super.initState(); cc = Passport.country.isEmpty ? 'EG' : Passport.country.toUpperCase(); _init(); }

  Future<void> _init() async {
    joined = await niloJoined();
    if (joined) { await _load(); } else if (mounted) { setState(() => busy = false); }
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try { await Sb.signIn(); rows = await Sb.get('tips?select=id,author,nick,body,created_at&place=eq.$cc&order=created_at.desc&limit=60') as List; } catch (_) { rows = []; }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _add() async {
    final t = c.text.trim();
    if (t.length < 5) { toast(context, 'Write at least a few words'); return; }
    final b = niloBad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    try {
      await Sb.post('tips', {'author': Sb.uid, 'nick': Passport.nickname.trim().length >= 2 ? Passport.nickname.trim() : 'Traveler', 'place': cc, 'body': t});
      c.clear();
      if (mounted) toast(context, 'Posted. • اتنشرت');
    } catch (_) { if (mounted) toast(context, 'Could not post (max 5 a day, no links or numbers).'); }
    _load();
  }

  Future<void> _menu(Map r) async {
    final mine = r['author'] == Sb.uid;
    final v = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: Text(L('Delete • احذف')), onTap: () => Navigator.pop(context, 'del')),
      if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: Text(L('Report • أبلغ')), onTap: () => Navigator.pop(context, 'rep')),
      if (!mine) ListTile(leading: const Icon(Icons.block), title: Text(L('Block • احظر')), onTap: () => Navigator.pop(context, 'blk')),
    ])));
    final id = r['id'].toString();
    if (v == 'del') { try { await Sb.delete('tips?id=eq.$id'); } catch (e, st) { Health.log(e, st); } }
    if (v == 'rep') { try { await Sb.rpc('report_tip', {'pid': id}); } catch (e, st) { Health.log(e, st); } if (mounted) toast(context, 'Reported. Thank you.'); }
    if (v == 'blk') { try { await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': r['author']}); } catch (e, st) { Health.log(e, st); } if (mounted) toast(context, 'Blocked.'); }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: Text(L('Local tips • نصايح محلية')), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : !joined
                ? niloJoinGate(context, _init)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    DropdownButton<String>(
                      value: kWorld.any((w) => w[0] == cc) ? cc : null,
                      isExpanded: true,
                      items: [for (final w in kWorld) DropdownMenuItem(value: w[0] as String, child: Text('${w[3]} ${Ui.rtl ? w[2] : w[1]}'))],
                      onChanged: (v) { if (v != null) { cc = v; _load(); } },
                    ),
                    TextField(controller: c, maxLength: 200, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: L('A tip for visitors, no places with numbers or links • نصيحة للزائر'), border: const OutlineInputBorder())),
                    FilledButton(onPressed: _add, child: Text(L('Share tip • انشر'))),
                    Text(L('Only general tips. No phone numbers, links or exact addresses.'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    if (rows.isEmpty) Text(L('No tips for this country yet.'), style: const TextStyle(color: Colors.white60)),
                    for (final r in rows)
                      Card(color: Colors.white10, child: ListTile(title: Text(r['body'].toString()), subtitle: Text((r['nick'] ?? '').toString()), onLongPress: () => _menu(r as Map), trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _menu(r as Map)))),
                  ]),
      );
}
