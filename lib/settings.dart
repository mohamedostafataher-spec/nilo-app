import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'screens.dart' show toast, openUrl;
import 'world.dart' show Passport;
import 'bottles.dart' show Sb;
import 'auth.dart';
import 'extras.dart' show niloRoute;
import 'home.dart' show TouristHome;
import 'store.dart';
import 'invite.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPrivacy = '''Privacy Policy • سياسة الخصوصية

Nilo is a free tourist and translation app made by Mohamed Mostafa Taher (Egypt).

What stays on your phone: your nickname, XP, streak, stamps, saved items and settings.

What goes to our server (Supabase) only when you use Papyrus, Stories or comments: the text, photo or short clip you post, your country code (two letters, for example EG), an anonymous random account id, your reactions, and reports or blocks you make. We never store your GPS coordinates. Your country is worked out on your phone and only the two-letter code is kept. If location is off, we use your phone region.

Translation: the text you type or say is sent to online translation services to give you the translation. Machine translation can be wrong. Do not rely on it for medical, legal or safety matters.

Stories and papyri disappear from view after 24 hours and are deleted from storage afterwards. Content that gets reported is hidden. Do not post phone numbers, links or personal details.

We do not sell data. There are no ads in this version. Nothing is sent to anyone automatically.

Age: Nilo social features are for people 18 or older. This is a self-declaration and we cannot verify it.

Delete your data: write to us from Settings > Report a problem and give your nickname. Local data is removed by clearing the app data or uninstalling.

This text is a plain-language draft, not legal advice. Last updated: 26 Nov 2026.''';

const kTerms = '''Terms of Use • شروط الاستخدام

1. You must be 18 or older to use Papyrus and Stories.
2. Be kind and neutral. No hate, harassment, nudity, violence, scams, politics or religion attacks.
3. No links, phone numbers or personal contact details in posts.
4. Meet people only in public places and stay alert to scams. Nilo is not responsible for meetings between users.
5. You are responsible for what you post. Reported content may be hidden or removed, and accounts that abuse the app may be blocked.
6. Translations and AI text are machine made and can be wrong. Use them as help, not as advice.
7. The app is provided as is, without guarantees.

This text is a plain-language draft, not legal advice. Last updated: 26 Nov 2026.''';

class TextDocPage extends StatelessWidget {
  final String title, body;
  const TextDocPage(this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), backgroundColor: kBg),
        body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: SelectableText(body, style: const TextStyle(height: 1.5, fontSize: 14))),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _taps = 0;
  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _editName() async {
    final c = TextEditingController(text: Passport.nickname);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nickname • الاسم'),
        content: TextField(controller: c, maxLength: 20, decoration: const InputDecoration(hintText: 'No real name needed')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save'))],
      ),
    );
    if (r != null && r.isNotEmpty) { setState(() => Passport.nickname = r); }
  }

  @override
  Widget build(BuildContext context) {
    Widget sw(String t, String sub, String k) => SwitchListTile(title: Text(t), subtitle: Text(sub, style: const TextStyle(fontSize: 12)), value: Passport.flag(k), onChanged: (v) => setState(() => Passport.setFlag(k, v)));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings • الإعدادات'), backgroundColor: kBg),
      body: ListView(children: [
        FutureBuilder<SharedPreferences>(future: SharedPreferences.getInstance(), builder: (c, snap) {
          final em = snap.data?.getString('acct_email');
          return ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(em == null ? 'Guest • ضيف' : 'Account • الحساب'),
            subtitle: Text(em ?? 'Create an account to keep your papyri'),
            trailing: TextButton(
              onPressed: () async {
                await Sb.signOut();
                if (!c.mounted) return;
                Navigator.of(c).pushAndRemoveUntil(niloRoute(AuthPage(next: const TouristHome())), (_) => false);
              },
              child: Text(em == null ? 'Sign in' : 'Sign out'),
            ),
          );
        }),
        ListTile(leading: const Icon(Icons.person), title: const Text('Profile • الملف'), subtitle: Text(Passport.nickname.isEmpty ? 'Set a nickname' : Passport.nickname), onTap: _editName),
        sw('Sound • الصوت', 'Sound effects in the app', 'sound'),
        SwitchListTile(title: const Text('Reduce motion • حركة أقل'), subtitle: const Text('Skips the send animation', style: TextStyle(fontSize: 12)), value: Passport.flag('reduce_motion', false), onChanged: (v) => setState(() => Passport.setFlag('reduce_motion', v))),
        SwitchListTile(
          title: const Text('Calm mode • وضع الهدوء'),
          subtitle: const Text('Fewer notifications, no send animation', style: TextStyle(fontSize: 12)),
          value: Passport.flag('calm', false),
          onChanged: (v) => setState(() { Passport.setFlag('calm', v); Passport.setFlag('reduce_motion', v); }),
        ),
        ListTile(leading: const Icon(Icons.storefront), title: Text('Store • المتجر  (${Passport.reeds} 🌿)'), subtitle: const Text('Spend Reeds on looks for your send animation'), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const StorePage())); setState(() {}); }),
        const Divider(),
        const ListTile(leading: Icon(Icons.shield), title: Text('Papyrus & Stories safety'), subtitle: Text('18+ only (self-declared). No links or phone numbers. Report or block anyone. Content hides after reports. Meet only in public places.')),
        ListTile(leading: const Icon(Icons.lock), title: const Text('Privacy policy • الخصوصية'), onTap: () => _go(const TextDocPage('Privacy Policy', kPrivacy))),
        ListTile(leading: const Icon(Icons.gavel), title: const Text('Terms of use • الشروط'), onTap: () => _go(const TextDocPage('Terms of Use', kTerms))),
        const Divider(),
        ListTile(leading: const Icon(Icons.share), title: const Text('Invite friends • ادعُ صديق'), subtitle: const Text('Your code, link and Reeds perks'), onTap: () => _go(const InvitePage())),
        ListTile(leading: const Icon(Icons.bug_report), title: const Text('Report a problem • أبلغ عن مشكلة'), onTap: () => openUrl('mailto:mohamedostafataher@gmail.com?subject=Nilo%20problem')),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About Nilo • عن نيلو'),
          subtitle: const Text('Created & Founded by Mohamed Mostafa Taher\nتطبيق مصري خالص • صُنع بواسطة Mohamed Mostafa'),
          isThreeLine: true,
          onTap: () => showAboutDialog(context: context, applicationName: 'Nilo • نيلو', applicationVersion: '1.5', children: const [Text('Created & Founded by Mohamed Mostafa Taher\nتطبيق مصري')]),
        ),
        ListTile(
          title: const Text('Version 1.5', style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () { _taps++; if (_taps >= 7) { _taps = 0; toast(context, 'Founder area is not built yet'); } },
        ),
      ]),
    );
  }
}
