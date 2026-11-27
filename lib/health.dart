import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Local crash log: the last 20 errors are kept on the phone only. Nothing is sent anywhere.
class Health {
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

  /// Compares the build with the public version.json. Returns the download URL when a newer build exists.
  static Future<String?> updateUrl() async {
    if (commit.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse('https://nilo-dl.vercel.app/version.json')).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final c = (j['commit'] ?? '').toString();
      if (c.isNotEmpty && !c.startsWith(commit) && !commit.startsWith(c)) return 'https://nilo-dl.vercel.app';
    } catch (_) {}
    return null;
  }

  static Future<void> offerUpdate(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (p.getString('upd_seen') == today) return;
    final u = await updateUrl();
    if (u == null || !context.mounted) return;
    await p.setString('upd_seen', today);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('A new Nilo version is ready • في نسخة جديدة من نيلو'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: 'Download • تحميل', onPressed: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)),
    ));
  }
}
