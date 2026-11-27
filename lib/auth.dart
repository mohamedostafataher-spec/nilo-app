import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'extras.dart' show niloRoute;
import 'bottles.dart' show Sb;
import 'settings.dart' show TextDocPage, kPrivacy, kTerms;
import 'world.dart' show NileBackground;

enum _Mode { signIn, signUp, forgot, verify }

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
    } else if (mode == _Mode.verify) {
      if (code.text.trim().length < 6) { setState(() { busy = false; error = L('Enter the code from your email'); }); return; }
      r = await Sb.verifyCode(code.text.trim());
    } else if (mode == _Mode.signUp) {
      if (pw.text.length < 8) { setState(() { busy = false; error = 'Password: at least 8 characters • كلمة السر 8 حروف على الأقل'; }); return; }
      r = await Sb.signUp(e, pw.text);
      if (r == Sb.kNeedCode) {
        setState(() { busy = false; mode = _Mode.verify; code.clear(); error = null; info = L('We sent a code to your email. Enter it to finish. If it does not arrive, check spam.'); });
        return;
      }
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
    final low = (r).toLowerCase();
    if (mode == _Mode.signUp && (low.contains('already') && (low.contains('registered') || low.contains('exists')))) {
      setState(() { busy = false; mode = _Mode.signIn; error = null; pw.clear(); info = L('This email already has an account. Sign in with your password. Forgot it? Use "Forgot password".'); });
      return;
    }
    if (mode == _Mode.signIn && low.contains('invalid login')) {
      setState(() { busy = false; error = L('Wrong email or password. If you never created an account with this email, tap "New here?".'); });
      return;
    }
    setState(() { busy = false; error = r; });
  }

  @override
  Widget build(BuildContext context) {
    final title = mode == _Mode.verify ? 'تأكيد الإيميل • Verify email' : mode == _Mode.signIn ? 'تسجيل الدخول • Sign in' : mode == _Mode.signUp ? 'إنشاء حساب • Create account' : 'نسيت كلمة السر • Forgot password';
    final tabs = (mode == _Mode.forgot || mode == _Mode.verify) ? <Widget>[] : <Widget>[
      Container(
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          for (final m in [_Mode.signIn, _Mode.signUp])
            Expanded(child: GestureDetector(
              onTap: () => setState(() { mode = m; error = null; info = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: mode == m ? const Color(0xFFD9A441) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Center(child: Text(L(m == _Mode.signIn ? 'Sign in • دخول' : 'Create account • إنشاء'), style: TextStyle(fontWeight: FontWeight.w800, color: mode == m ? const Color(0xFF0B1F33) : Colors.white70))),
              ),
            )),
        ]),
      ),
      const SizedBox(height: 16),
    ];
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: NileBackground()),
        SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), children: [
          const SizedBox(height: 14),
          Center(child: Container(
            width: 84, height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFD9A441), Color(0xFF8E6A1E)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: const Color(0xFFD9A441).withOpacity(0.35), blurRadius: 24)]),
            child: const Center(child: Text('𓂀', style: TextStyle(fontSize: 42, color: Color(0xFF0B1F33)))),
          )),
          const SizedBox(height: 12),
          Center(child: Text(L('Nilo • نيلو'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1))),
          Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(L('Translate, travel, connect • ترجم، سافر، تواصل'), style: const TextStyle(color: Colors.white60, fontSize: 13)))),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF0E2A45).withOpacity(0.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...tabs,
          if (mode == _Mode.forgot || mode == _Mode.verify) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(L(title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: InputDecoration(prefixIcon: const Icon(Icons.mail_outline), labelText: L('Email • الإيميل'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
          const SizedBox(height: 12),
          if (mode == _Mode.verify) ...[
            TextField(controller: code, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: L('Code from email • الكود'), border: const OutlineInputBorder())),
            TextButton(onPressed: busy ? null : () async { final r = await Sb.resendCode(); if (mounted) setState(() { error = r; info = r == null ? L('Code sent again.') : null; }); }, child: Text(L('Send the code again'))),
          ] else if (mode != _Mode.forgot || codeSent) ...[
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
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: busy ? null : _submit,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(mode == _Mode.verify ? 'Verify • تأكيد' : mode == _Mode.signIn ? 'Sign in • دخول' : mode == _Mode.signUp ? 'Create account • إنشاء' : (codeSent ? 'Set new password' : 'Send code • ابعت الكود'))),
          ),
          const SizedBox(height: 6),
          if (mode == _Mode.signIn) ...[
            TextButton(onPressed: () => setState(() { mode = _Mode.forgot; error = null; info = null; codeSent = false; }), child: Text(L('Forgot password? • نسيت كلمة السر؟'))),
            TextButton(onPressed: () => setState(() { mode = _Mode.signUp; error = null; }), child: Text(L('New here? Create an account • حساب جديد'))),
          ] else
            TextButton(onPressed: () => setState(() { mode = _Mode.signIn; error = null; info = null; }), child: Text(L('Back to sign in • رجوع'))),
            ]),
          ),
          const SizedBox(height: 18),
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
      ]),
    );
  }
}
