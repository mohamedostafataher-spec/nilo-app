import 'i18n.dart';
import 'places.dart';
import 'profile.dart';
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
        appBar: AppBar(title: Text(L(title)), backgroundColor: kBg),
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
        title: Text(L('Nickname • الاسم')),
        content: TextField(controller: c, maxLength: 20, decoration: InputDecoration(hintText: L('No real name needed'))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L('Cancel'))), TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(L('Save')))],
      ),
    );
    if (r != null && r.isNotEmpty) { setState(() => Passport.nickname = r); }
  }

  @override
  Widget build(BuildContext context) {
    Widget sw(String t, String sub, String k) => SwitchListTile(title: Text(L(t)), subtitle: Text(L(sub), style: TextStyle(fontSize: 12)), value: Passport.flag(k), onChanged: (v) => setState(() => Passport.setFlag(k, v)));
    return Scaffold(
      appBar: AppBar(title: Text(L('Settings • الإعدادات')), backgroundColor: kBg),
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
        ListTile(leading: Icon(Icons.person), title: Text(L('Profile • الملف')), subtitle: Text(Passport.nickname.isEmpty ? 'Set a nickname' : Passport.nickname), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEditPage())); setState(() {}); }),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(L('Interface language • لغة التطبيق')),
          subtitle: Text(Ui.pref == 'auto' ? L('Automatic (phone) • تلقائي (التليفون)') : Ui.pref == 'ar' ? 'العربية' : 'English'),
          onTap: () async {
            final v = await showDialog<String>(context: context, builder: (c) => SimpleDialog(
              title: Text(L('Interface language • لغة التطبيق')),
              children: [
                for (final o in const [['auto', 'Automatic (phone) • تلقائي (التليفون)'], ['ar', 'العربية'], ['en', 'English']])
                  SimpleDialogOption(onPressed: () => Navigator.pop(c, o[0]), child: Text(L(o[1]))),
              ]));
            if (v != null) { await Ui.set(v); if (mounted) setState(() {}); }
          },
        ),
        sw('Sound • الصوت', 'Sound effects in the app', 'sound'),
        SwitchListTile(title: Text(L('Reduce motion • حركة أقل')), subtitle: Text(L('Skips the send animation'), style: TextStyle(fontSize: 12)), value: Passport.flag('reduce_motion', false), onChanged: (v) => setState(() => Passport.setFlag('reduce_motion', v))),
        SwitchListTile(
          title: Text(L('Calm mode • وضع الهدوء')),
          subtitle: Text(L('Fewer notifications, no send animation'), style: TextStyle(fontSize: 12)),
          value: Passport.flag('calm', false),
          onChanged: (v) => setState(() { Passport.setFlag('calm', v); Passport.setFlag('reduce_motion', v); }),
        ),
        ListTile(leading: Icon(Icons.public), title: Text(L('Notable places • أماكن مميزة')), subtitle: Text(L('UNESCO sites in any country (live, Wikidata)')), onTap: () => _go(PlacesOfPage())),
        ListTile(leading: Icon(Icons.storefront), title: Text('Store • المتجر  (${Passport.reeds} 🌿)'), subtitle: Text(L('Spend Reeds on looks for your send animation')), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => StorePage())); setState(() {}); }),
        const Divider(),
        ListTile(leading: Icon(Icons.shield), title: Text(L('Papyrus & Stories safety')), subtitle: Text(L('18+ only (self-declared). No links or phone numbers. Report or block anyone. Content hides after reports. Meet only in public places.'))),
        ListTile(leading: Icon(Icons.lock), title: Text(L('Privacy policy • الخصوصية')), onTap: () => _go(TextDocPage('Privacy Policy', kPrivacy))),
        ListTile(leading: Icon(Icons.gavel), title: Text(L('Terms of use • الشروط')), onTap: () => _go(TextDocPage('Terms of Use', kTerms))),
        const Divider(),
        ListTile(leading: Icon(Icons.share), title: Text(L('Invite friends • ادعُ صديق')), subtitle: Text(L('Your code, link and Reeds perks')), onTap: () => _go(InvitePage())),
        ListTile(leading: Icon(Icons.bug_report), title: Text(L('Report a problem • أبلغ عن مشكلة')), onTap: () => openUrl('mailto:mohamedostafataher@gmail.com?subject=Nilo%20problem')),
        ListTile(
          leading: const Icon(Icons.info),
          title: Text(L('About Nilo • عن نيلو')),
          subtitle: Text(L('Created & Founded by Mohamed Mostafa Taher\nتطبيق مصري خالص • صُنع بواسطة Mohamed Mostafa')),
          isThreeLine: true,
          onTap: () => showAboutDialog(context: context, applicationName: 'Nilo • نيلو', applicationVersion: '1.5', children: [Text(L('Created & Founded by Mohamed Mostafa Taher\nتطبيق مصري'))]),
        ),
        ListTile(
          title: Text(L('Version 1.5'), style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () { _taps++; if (_taps >= 7) { _taps = 0; toast(context, 'Founder area is not built yet'); } },
        ),
      ]),
    );
  }
}
