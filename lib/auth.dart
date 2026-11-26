import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'extras.dart' show niloRoute;
import 'bottles.dart' show Sb;
import 'settings.dart' show TextDocPage, kPrivacy, kTerms;

enum _Mode { signIn, signUp, forgot }

/// Shown after the splash. Email + password accounts (Supabase Auth). Guest mode keeps working.
class AuthPage extends StatefulWidget {
  final Widget next;
  const AuthPage({super.key, required this.next});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  _Mode mode = _Mode.signIn;
  final email = TextEditingController(), pw = TextEditingController(), code = TextEditingController();
  bool busy = false, codeSent = false, show = false;
  String? error, info;

  Future<void> _done() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('auth_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(niloRoute(widget.next));
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());

  Future<void> _submit() async {
    setState(() { error = null; info = null; });
    final e = email.text.trim();
    if (!_emailOk) { setState(() => error = 'Enter a valid email • اكتب إيميل صحيح'); return; }
    setState(() => busy = true);
    String? r;
    if (mode == _Mode.signIn) {
      if (pw.text.isEmpty) { setState(() { busy = false; error = 'Enter your password • اكتب كلمة السر'; }); return; }
      r = await Sb.signInPassword(e, pw.text);
    } else if (mode == _Mode.signUp) {
      if (pw.text.length < 8) { setState(() { busy = false; error = 'Password: at least 8 characters • كلمة السر 8 حروف على الأقل'; }); return; }
      r = await Sb.signUp(e, pw.text);
    } else if (!codeSent) {
      r = await Sb.sendResetCode(e);
      if (r == null) { setState(() { codeSent = true; info = 'We sent a code to your email. If it does not arrive, check spam. • بعتنالك كود على الإيميل'; }); }
      setState(() { busy = false; error = r; });
      return;
    } else {
      if (code.text.trim().isEmpty || pw.text.length < 8) { setState(() { busy = false; error = 'Enter the code and a new password (8+ characters)'; }); return; }
      r = await Sb.resetWithCode(e, code.text.trim(), pw.text);
    }
    if (!mounted) return;
    if (r == null) { await _done(); return; }
    setState(() { busy = false; error = r; });
  }

  @override
  Widget build(BuildContext context) {
    final title = mode == _Mode.signIn ? 'تسجيل الدخول • Sign in' : mode == _Mode.signUp ? 'إنشاء حساب • Create account' : 'نسيت كلمة السر • Forgot password';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 20),
          Center(child: Text(L('𓂀'), style: TextStyle(fontSize: 48, color: Color(0xFFE0B04A)))),
          Center(child: Text(L('Nilo • نيلو'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
          const SizedBox(height: 24),
          Text(L(title), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: InputDecoration(labelText: L('Email • الإيميل'), border: OutlineInputBorder())),
          const SizedBox(height: 10),
          if (mode != _Mode.forgot || codeSent) ...[
            if (mode == _Mode.forgot) ...[
              TextField(controller: code, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: L('Code from email • الكود'), border: OutlineInputBorder())),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: pw, obscureText: !show,
              decoration: InputDecoration(labelText: mode == _Mode.forgot ? 'New password • كلمة سر جديدة' : 'Password • كلمة السر', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => show = !show))),
            ),
          ],
          if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
          if (info != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(info!, style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(mode == _Mode.signIn ? 'Sign in • دخول' : mode == _Mode.signUp ? 'Create account • إنشاء' : (codeSent ? 'Set new password' : 'Send code • ابعت الكود'))),
          ),
          const SizedBox(height: 6),
          if (mode == _Mode.signIn) ...[
            TextButton(onPressed: () => setState(() { mode = _Mode.forgot; error = null; info = null; codeSent = false; }), child: Text(L('Forgot password? • نسيت كلمة السر؟'))),
            TextButton(onPressed: () => setState(() { mode = _Mode.signUp; error = null; }), child: Text(L('New here? Create an account • حساب جديد'))),
          ] else
            TextButton(onPressed: () => setState(() { mode = _Mode.signIn; error = null; info = null; }), child: Text(L('Back to sign in • رجوع'))),
          const Divider(height: 28),
          OutlinedButton(onPressed: busy ? null : _done, child: Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text(L('Continue as guest • كمل كضيف')))),
          const SizedBox(height: 6),
          Text(L('A guest account lives on this phone only. If you lose the phone you lose it. Create an account to keep your papyri.'), style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, children: [
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TextDocPage('Privacy Policy', kPrivacy))), child: Text(L('Privacy'), style: TextStyle(fontSize: 12))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TextDocPage('Terms of Use', kTerms))), child: Text(L('Terms'), style: TextStyle(fontSize: 12))),
          ]),
        ]),
      ),
    );
  }
}
