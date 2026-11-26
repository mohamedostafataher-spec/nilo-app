import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'world.dart';
import 'bottles.dart';
import 'screens.dart' show toast;
import 'circles.dart' show niloJoined, niloJoinGate;

/// Invites: your personal code, how many friends joined with it, and a field for a friend's code.
/// Perks: +10 Reeds for you per friend who enters your code, +20 Reeds for the friend. Reeds are cosmetics only.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});
  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  bool joined = false, busy = true;
  String code = '';
  int count = 0, gained = 0;
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    joined = await niloJoined();
    if (joined) {
      try {
        await Sb.signIn();
        code = ((await Sb.rpc('my_invite_code')) ?? '').toString();
        count = ((await Sb.rpc('invite_count')) as num?)?.toInt() ?? 0;
        final p = await SharedPreferences.getInstance();
        final claimed = p.getInt('inv_claimed') ?? 0;
        if (count > claimed) { gained = (count - claimed) * 10; Passport.addReeds(gained); await p.setInt('inv_claimed', count); }
      } catch (_) {}
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _redeem() async {
    final t = c.text.trim();
    if (t.isEmpty) return;
    try {
      final ok = await Sb.rpc('redeem_invite', {'c': t});
      if (ok == true) { Passport.addReeds(20); if (mounted) toast(context, 'Done. +20 Reeds. • تم'); c.clear(); }
      else if (mounted) { toast(context, 'That code did not work, or you already used one.'); }
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  @override
  Widget build(BuildContext context) {
    final msg = 'Nilo • https://nilo-dl.vercel.app  (my invite code: $code)';
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Invite friends • ادعُ أصحابك')), backgroundColor: kBg),
      body: !joined
          ? (busy ? const Center(child: CircularProgressIndicator()) : niloJoinGate(context, _init))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(L('Your code • كودك')),
                  const SizedBox(height: 6),
                  SelectableText(code.isEmpty ? '...' : code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 3, color: kGreen)),
                  const SizedBox(height: 8),
                  Text(Ui.rtl ? 'انضم $count من أصحابك بكودك' : '$count friend${count == 1 ? '' : 's'} joined with your code', style: TextStyle(color: Colors.white70)),
                  if (gained > 0) Text(Ui.rtl ? 'اتضاف +$gained ريدز دلوقتي' : '+$gained Reeds added now', style: TextStyle(color: kGreen)),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: code.isEmpty ? null : () { Clipboard.setData(ClipboardData(text: msg)); toast(context, 'Copied. Paste it to a friend. • اتنسخ'); }, icon: Icon(Icons.copy), label: Text(L('Copy link + code'))),
                ]),
              ),
              const SizedBox(height: 16),
              Text(L('Got a friend\'s code? • معاك كود صاحبك؟'), style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(controller: c, maxLength: 12, decoration: InputDecoration(counterText: '', hintText: L('Code')))),
                const SizedBox(width: 8),
                FilledButton(onPressed: _redeem, child: Text(L('Use'))),
              ]),
              const SizedBox(height: 14),
              Text(L('You get +10 Reeds for every friend who enters your code, and the friend gets +20. One code per person. Reeds only buy looks in the store, never money. Counts are checked on the server; Reeds are kept on the phone.'), style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
            ]),
    );
  }
}
