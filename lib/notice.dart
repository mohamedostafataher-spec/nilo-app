import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bottles.dart';
import 'health.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;

/// Top-of-home notices: (1) a new build is available (compares the build commit with version.json on the download page),
/// (2) the latest announcement written by the founder. Each can be dismissed; a new announcement shows again.
class NoticeBar extends StatefulWidget {
  const NoticeBar({super.key});
  @override
  State<NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<NoticeBar> {
  String? upd;
  Map? ann;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    String? u;
    try { u = await Health.updateUrl(); } catch (_) {}
    Map? a;
    try {
      await Sb.signIn();
      final r = await Sb.get('announcements?select=id,title,body&active=eq.true&order=created_at.desc&limit=1') as List;
      if (r.isNotEmpty && p.getString('ann_seen') != r.first['id'].toString()) a = r.first as Map;
    } catch (_) {}
    if (mounted) setState(() { upd = u; ann = a; });
  }

  Widget _bar(Color c, String text, String? sub, String? action, VoidCallback? go, VoidCallback close) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            if (sub != null && sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
          if (action != null) TextButton(onPressed: go, child: Text(action)),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: close),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (upd != null) _bar(const Color(0xFF1B5E4B), L('A new Nilo version is ready • في نسخة جديدة من نيلو'), null, L('Download • تحميل'),
          () => launchUrl(Uri.parse(upd!), mode: LaunchMode.externalApplication), () => setState(() => upd = null)),
      if (ann != null) _bar(const Color(0xFF3A2C6B), (ann!['title'] ?? '').toString(), (ann!['body'] ?? '').toString(), null, null, () async {
        final p = await SharedPreferences.getInstance();
        await p.setString('ann_seen', ann!['id'].toString());
        if (mounted) setState(() => ann = null);
      }),
    ]);
  }
}

/// Founder area (tap the version line 7 times in Settings). The server only answers to the founder account,
/// so for anyone else every call fails. Shows totals only: no names, no messages, no locations.
class FounderPage extends StatefulWidget {
  const FounderPage({super.key});
  @override
  State<FounderPage> createState() => _FounderPageState();
}

class _FounderPageState extends State<FounderPage> {
  Map? stats;
  List reports = [];
  bool busy = true, denied = false;
  final t = TextEditingController(), b = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      await Sb.signIn();
      stats = Map.from((await Sb.rpc('founder_stats')) as Map);
      reports = (await Sb.rpc('founder_reports') as List?) ?? [];
    } catch (_) { denied = true; }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _post() async {
    if (t.text.trim().isEmpty) return;
    try { await Sb.rpc('founder_announce', {'p_title': t.text.trim(), 'p_body': b.text.trim()}); t.clear(); b.clear(); if (mounted) toast(context, 'Posted. Everyone sees it on the home page.'); } catch (_) { if (mounted) toast(context, 'Did not work.'); }
  }

  Future<void> _remove(Map r) async {
    try { await Sb.rpc('founder_remove', {'p_kind': r['kind'], 'p_id': r['id']}); } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: const Text('المؤسس • Founder'), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : denied
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(L('This area is only for the founder account. Sign in with the founder email first.'), textAlign: TextAlign.center)))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(L('Totals (no personal data) • أرقام إجمالية'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.7, mainAxisSpacing: 10, crossAxisSpacing: 10, children: [
                      for (final c in const [
                        ['members', 'الأعضاء • Members', Icons.people_alt_outlined],
                        ['papyri_total', 'كل البرديات • All papyri', Icons.mail_outline],
                        ['papyri_24h', 'برديات آخر 24 ساعة • Papyri 24h', Icons.bolt_outlined],
                        ['stories_24h', 'قصص 24 ساعة • Stories 24h', Icons.photo_outlined],
                        ['answers_24h', 'إجابات 24 ساعة • Answers 24h', Icons.quiz_outlined],
                        ['friends', 'صداقات • Friendships', Icons.favorite_border],
                        ['groups', 'مجموعات • Groups', Icons.groups_outlined],
                        ['chains', 'سلاسل • Chains', Icons.link],
                        ['reported_items', 'بلاغات • Reports', Icons.flag_outlined],
                      ])
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Icon(c[2] as IconData, color: const Color(0xFFE0B04A), size: 20),
                            Text('${stats?[c[0]] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                            Text(c[1] as String, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Text(L('Countries (top 10) • الدول'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final m = ((stats?['countries'] ?? {}) as Map).entries.toList();
                      if (m.isEmpty) return Text(L('No data yet.'), style: const TextStyle(color: Colors.white60));
                      final mx = m.map((e) => (e.value as num).toDouble()).reduce((x, y) => x > y ? x : y);
                      return Column(children: [
                        for (final e in m)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                            SizedBox(width: 34, child: Text('${e.key}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: mx == 0 ? 0 : (e.value as num) / mx, minHeight: 10, backgroundColor: Colors.white12, color: const Color(0xFFE0B04A)))),
                            SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                          ])),
                      ]);
                    }),
                    const Divider(),
                    Text(L('Announcement • إعلان'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextField(controller: t, maxLength: 80, decoration: const InputDecoration(hintText: 'Title')),
                    TextField(controller: b, maxLength: 400, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Text')),
                    Row(children: [
                      FilledButton(onPressed: _post, child: Text(L('Post • انشر'))),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () async { try { await Sb.rpc('founder_clear_announce'); if (mounted) toast(context, 'Cleared.'); } catch (_) {} }, child: Text(L('Clear • امسح'))),
                    ]),
                    const Divider(),
                    Text('${L('Reported items • بلاغات')} (${reports.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (reports.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(L('Nothing reported.'), style: const TextStyle(color: Colors.white60))),
                    for (final r in reports)
                      Card(color: Colors.white10, child: ListTile(
                        title: Text((r['body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${r['kind']} • ${r['reports']} reports'),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _remove(r as Map)),
                      )),
                  ]),
      );
}
