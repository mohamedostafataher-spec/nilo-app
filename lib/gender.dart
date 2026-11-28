import 'health.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bottles.dart' show Sb;
import 'i18n.dart';

/// Self-declared gender ('m' or 'f'). Shown on profiles and used for the 3D avatar body.
class Gender {
  static Future<String> get() async => (await SharedPreferences.getInstance()).getString('p_gender') ?? '';

  /// Saves on the phone first, then tries to sync to the profile. Retries on the next launch if offline.
  static Future<void> set(String g) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('p_gender', g);
    await p.setBool('p_gender_sync', false);
    await sync();
  }

  static Future<void> sync() async {
    try {
      final p = await SharedPreferences.getInstance();
      final g = p.getString('p_gender') ?? '';
      if (g.isEmpty || (p.getBool('p_gender_sync') ?? false)) return;
      if (!await Sb.signIn()) return;
      await Sb.rpc('set_gender', {'p_g': g});
      await p.setBool('p_gender_sync', true);
    } catch (e, st) { Health.log(e, st); }
  }

  static String label(String g) => g == 'f' ? L('Female • أنثى') : g == 'm' ? L('Male • ذكر') : '';
  static String icon(String g) => g == 'f' ? '\u2640' : g == 'm' ? '\u2642' : '';

  /// Asks once (existing and new users). Cannot be dismissed without an answer.
  static Future<void> ensure(BuildContext context) async {
    final g = await get();
    if (g.isNotEmpty) { sync(); return; }
    if (!context.mounted) return;
    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(L('Are you a man or a woman? • أنت ذكر ولا أنثى؟')),
        content: Text(L('This is shown on your profile so people know who they are talking to, and it sets your 3D avatar body. You can change it later in your profile.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'm'), child: Text(L('Male • ذكر'))),
          TextButton(onPressed: () => Navigator.pop(c, 'f'), child: Text(L('Female • أنثى'))),
        ],
      ),
    );
    if (r != null) await set(r);
  }
}
