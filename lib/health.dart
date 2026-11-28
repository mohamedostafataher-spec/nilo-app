import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'bottles.dart' show Sb;

/// Local crash log: the last 20 errors are kept on the phone only. Nothing is sent anywhere.
class Health {
  static int _n = 0, _slow = 0;
  static bool _perfDone = false;

  /// Slow-phone safeguard: if more than 40% of the first 240 frames take over 40 ms, turn on Reduce motion once.
  /// The setting stays visible in Settings, so the user can switch it off. Nothing leaves the phone.
  static void watchPerf() {
    SchedulerBinding.instance.addTimingsCallback((ts) async {
      if (_perfDone) return;
      for (final t in ts) {
        _n++;
        if (t.totalSpan.inMilliseconds > 40) _slow++;
      }
      if (_n >= 240) {
        _perfDone = true;
        final p = await SharedPreferences.getInstance();
        if (!(p.getBool('perf_checked') ?? false)) {
          await p.setBool('perf_checked', true);
          if (_slow / _n > 0.4) await p.setBool('f_reduce_motion', true);
        }
      }
    });
  }

  static Future<void> log(Object e, [StackTrace? s]) async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('err_log') ?? <String>[];
      final line = '${DateTime.now().toUtc().toIso8601String()} ${e.toString().split('\n').first}';
      l.add(line.length > 300 ? line.substring(0, 300) : line);
      while (l.length > 20) { l.removeAt(0); }
      await p.setStringList('err_log', l);
    } catch (_) {}
  }

  static Future<List<String>> read() async => (await SharedPreferences.getInstance()).getStringList('err_log') ?? <String>[];
  static Future<void> clear() async => (await SharedPreferences.getInstance()).remove('err_log');

  /// Build commit, set by CI with --dart-define=NILO_COMMIT. Empty in local builds.
  static const commit = String.fromEnvironment('NILO_COMMIT');

  /// Monotonic build number set by CI (--dart-define=NILO_BUILD=run number). 0 in local builds.
  static const build = int.fromEnvironment('NILO_BUILD');

  /// Returns the download URL only when version.json lists a higher build number than this installed build.
  static List<String> lastChangelog = [];
  static String lastVersion = '';

  static Future<String?> updateUrl() async {
    if (build <= 0) return null;
    try {
      final r = await http.get(Uri.parse('https://mohamedostafataher-spec.github.io/nilo-dl/version.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}')).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final n = int.tryParse((j['build'] ?? '').toString()) ?? 0;
      if (n > build) {
        lastVersion = (j['version'] ?? '').toString();
        lastChangelog = ((j['changelog'] ?? []) as List).map((e) => e.toString()).toList();
        return 'https://mohamedostafataher-spec.github.io/nilo-dl';
      }
    } catch (e, st) { log(e, st); }
    return null;
  }

  /// Clear dialog with the release notes and a Download button. Shown at most once per day; the top notice bar stays until the user updates.
  static Future<void> offerUpdate(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (p.getString('upd_seen') == today) return;
    final u = await updateUrl();
    if (u == null || !context.mounted) return;
    await p.setString('upd_seen', today);
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text('New Nilo version $lastVersion • نسخة جديدة'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lastChangelog.take(6)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $l')),
        const SizedBox(height: 8),
        const Text('Your data and account stay. The new version installs over this one. • بياناتك وحسابك بيفضلوا.', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later • بعدين')),
        FilledButton(onPressed: () { launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication); Navigator.pop(c); }, child: const Text('Download • تحميل')),
      ],
    ));
  }

  /// Unread replies on my papyri, shown as a badge on the Messages tab.
  static final unread = ValueNotifier<int>(0);

  static Future<Map<String, int>> _seen() async {
    final p = await SharedPreferences.getInstance();
    try { return (jsonDecode(p.getString('seen_replies') ?? '{}') as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())); } catch (_) { return {}; }
  }

  static Future<void> markSeen(List<dynamic> bottles) async {
    final m = await _seen();
    for (final b in bottles) {
      final reps = ((b as Map)['replies'] ?? []) as List;
      m[b['id'].toString()] = reps.where((r) => (r as Map)['author'] != Sb.uid).length;
    }
    (await SharedPreferences.getInstance()).setString('seen_replies', jsonEncode(m));
    unread.value = 0;
  }

  static Future<void> refreshUnread() async {
    try {
      if (await Sb.loadGuest()) { unread.value = 0; return; }
      if (!await Sb.signIn()) return;
      final r = await Sb.get('bottles?select=id,author,replies(id,author)&order=created_at.desc&limit=50') as List;
      final seen = await _seen();
      var n = 0;
      for (final b in r) {
        final theirs = (((b as Map)['replies'] ?? []) as List).where((x) => (x as Map)['author'] != Sb.uid).length;
        if (theirs > (seen[b['id'].toString()] ?? 0)) n++;
      }
      unread.value = n;
    } catch (_) {}
  }

  /// Copies the user's own papyri (and replies they wrote) to the clipboard as text. Nothing leaves the phone otherwise.
  static Future<String?> exportMine() async {
    try {
      if (!await Sb.signIn()) return 'No connection. Try again.';
      final r = await Sb.get('bottles?select=body,kind,place,lang,created_at,status,replies(body,author,created_at)&author=eq.${Sb.uid}&order=created_at.desc&limit=200');
      final out = {'exported_at': DateTime.now().toUtc().toIso8601String(), 'papyri_sent': r};
      await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(out)));
      return null;
    } catch (e) { return 'Could not export. Try again.'; }
  }
}
