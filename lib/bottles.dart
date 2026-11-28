import 'gallery.dart';
import 'gender.dart';
import 'friends.dart' show DmPage;
import 'journey.dart';
import 'health.dart';
import 'dart:async';
import 'auth.dart' show AuthPage;
import 'home.dart' show TouristHome;
import 'i18n.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'main.dart';
import 'world.dart';
import 'net.dart';
import 'screens.dart';
import 'sendfx.dart';
import 'profile.dart' show AvatarView;
import 'games.dart' show saveWord;

const _sbUrl = 'https://fbfvjihrbzsqlwmoejiq.supabase.co';
const _sbKey = 'sb_publishable_3Gw07lMxemop4QhYpgUszw_8jlkb5JP';

/// Minimal Supabase REST client (anonymous sign-in + RLS-protected tables).
class Sb {
  static String? _token;
  static String? uid;
  static String get baseUrl => _sbUrl;
  static String get anonKey => _sbKey;
  static String? get token => _token;

  static Map<String, String> _h([bool auth = true]) => {
        'apikey': _sbKey,
        'Content-Type': 'application/json',
        if (auth && _token != null) 'Authorization': 'Bearer $_token',
      };

  static String? _healed, _ccSynced;
  /// Signs in and guarantees a profiles row exists (stories, reactions, comments, papyri all need it).
  static Future<bool> signIn() async {
    final ok = await _signIn0();
    if (ok && uid != null && _ccSynced != uid && Passport.country.length == 2) {
      try { await rpc('nilo_set_cc', {'c': Passport.country}); _ccSynced = uid; } catch (e, st) { Health.log(e, st); }
    }
    if (ok && uid != null && _healed != uid) {
      try {
        final p = await SharedPreferences.getInstance();
        var n = (p.getString('b_nick') ?? '').trim();
        if (n.length < 2) n = Passport.nickname.trim();
        final has = await get('profiles?select=id&id=eq.$uid') as List;
        if (has.isEmpty && n.length >= 2 && (p.getBool('b_age') ?? true)) {
          await post('profiles', {'id': uid, 'nick': n, 'lang': p.getString('b_lang') ?? 'en', 'age_ok': true}, upsert: true);
          await p.setBool('b_age', true); await p.setString('b_nick', n);
        }
        if (has.isNotEmpty || n.length >= 2) _healed = uid;
      } catch (e, st) { Health.log(e, st); }
    }
    return ok;
  }

  static DateTime? _tokAt;
  static Future<bool> _signIn0() async {
    if (_token != null && uid != null && _tokAt != null && DateTime.now().difference(_tokAt!).inMinutes < 45) return true;
    final p = await SharedPreferences.getInstance();
    final rt = p.getString('sb_rt');
    if (rt != null) {
      try {
        final r = await http.post(Uri.parse('$_sbUrl/auth/v1/token?grant_type=refresh_token'), headers: _h(false), body: jsonEncode({'refresh_token': rt})).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          _save(p, jsonDecode(r.body));
          return true;
        }
      } catch (e, st) { Health.log(e, st); }
    }
    try {
      final r = await http.post(Uri.parse('$_sbUrl/auth/v1/signup'), headers: _h(false), body: jsonEncode({'data': {}})).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        _save(p, jsonDecode(r.body));
        return true;
      }
    } catch (e, st) { Health.log(e, st); }
    return false;
  }

  // ---- Accounts (Supabase Auth: email + password, email code for reset) ----
  static String _err(http.Response r) {
    try { final j = jsonDecode(utf8.decode(r.bodyBytes)); return (j['msg'] ?? j['error_description'] ?? j['message'] ?? j['error'] ?? 'Error ${r.statusCode}').toString(); } catch (_) { return 'Error ${r.statusCode}'; }
  }
  static Future<String?> _authCall(Future<http.Response> f, SharedPreferences p, {bool save = true}) async {
    try {
      final r = await f.timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) return _err(r);
      if (save) { final j = jsonDecode(utf8.decode(r.bodyBytes)); if (j is Map && j['access_token'] != null) _save(p, j); }
      return null;
    } catch (_) { return 'No connection'; }
  }
  /// Email codes are on when the server setting "Confirm email" is on. The app adapts: if the server
  /// returns a session, no code is needed; otherwise it asks for the emailed code.
  static const kNeedCode = 'NEED_CODE';
  static Future<String?> signUp(String email, String pw) async {
    final p = await SharedPreferences.getInstance();
    final hasSession = p.getString('sb_rt') != null && await _refresh(p);
    try {
      if (hasSession) {
        final r = await http.put(Uri.parse('$_sbUrl/auth/v1/user'), headers: _h(), body: jsonEncode({'email': email, 'password': pw})).timeout(const Duration(seconds: 20));
        if (r.statusCode >= 300) return _err(r);
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['new_email'] != null) { await p.setString('pend_email', email); await p.setString('pend_type', 'email_change'); return kNeedCode; }
        await p.setString('acct_email', email); guest = false;
        return null;
      }
      final r = await http.post(Uri.parse('$_sbUrl/auth/v1/signup'), headers: _h(false), body: jsonEncode({'email': email, 'password': pw})).timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) return _err(r);
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['access_token'] != null) { _save(p, j); await p.setString('acct_email', email); guest = false; return null; }
      await p.setString('pend_email', email); await p.setString('pend_type', 'signup');
      return kNeedCode;
    } catch (_) { return 'No connection'; }
  }
  static Future<bool> _refresh(SharedPreferences p) async {
    try {
      final r = await http.post(Uri.parse('$_sbUrl/auth/v1/token?grant_type=refresh_token'), headers: _h(false), body: jsonEncode({'refresh_token': p.getString('sb_rt')})).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) { _save(p, jsonDecode(r.body)); return true; }
    } catch (e, st) { Health.log(e, st); }
    return false;
  }
  static Future<String?> verifyCode(String code) async {
    final p = await SharedPreferences.getInstance();
    final email = p.getString('pend_email') ?? '';
    final type = p.getString('pend_type') ?? 'signup';
    final e = await _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/verify'), headers: _h(false), body: jsonEncode({'type': type, 'email': email, 'token': code})), p);
    if (e == null) { await p.setString('acct_email', email); await p.remove('pend_email'); await p.remove('pend_type'); guest = false; }
    return e;
  }
  static Future<String?> resendCode() async {
    final p = await SharedPreferences.getInstance();
    final email = p.getString('pend_email') ?? '';
    final type = p.getString('pend_type') ?? 'signup';
    return _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/resend'), headers: _h(type == 'email_change'), body: jsonEncode({'type': type, 'email': email})), p, save: false);
  }
  static bool guest = true;
  static Future<bool> loadGuest() async { final p = await SharedPreferences.getInstance(); guest = (p.getString('acct_email') ?? '').isEmpty; return guest; }
  /// Guests can look around; posting needs a free account. Returns true when the action must stop.
  static Future<bool> needAccount(BuildContext context) async {
    if (!await loadGuest()) return false;
    if (!context.mounted) return true;
    final go = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(L('Create a free account')),
      content: Text(L('Guests can browse and translate. To post, react, comment or send papyri you need a free account. It also keeps your papyri if you change phone.')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Not now'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Create account')))],
    ));
    if (go == true && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthPage(next: const TouristHome())));
    }
    return true;
  }
  /// Call from a write screen's initState: guests are asked before they type anything.
  static void gateOpen(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await loadGuest() || !context.mounted) return;
      final go = await showDialog<bool>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
        title: Text(L('Create a free account')),
        content: Text(L('Guests can browse and translate. To post, react, comment or send papyri you need a free account. It also keeps your papyri if you change phone.')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Not now'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Create account')))],
      ));
      if (!context.mounted) return;
      if (go == true) { Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AuthPage(next: const TouristHome()))); }
      else { Navigator.of(context).pop(); }
    });
  }

  /// Deletes the account and everything tied to it on the server, then clears this phone.
  static Future<String?> deleteAccount() async {
    try {
      await wipeMyFiles();
      await rpc('delete_my_account');
      await signOut();
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().toList()) { if (k.startsWith('b_') || k == 'pend_email' || k == 'pend_type') await p.remove(k); }
      guest = true; _healed = null;
      return null;
    } catch (_) { return 'Could not delete. Check your connection and try again.'; }
  }
  static Future<String?> signInPassword(String email, String pw) async {
    final p = await SharedPreferences.getInstance();
    final e = await _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/token?grant_type=password'), headers: _h(false), body: jsonEncode({'email': email, 'password': pw})), p);
    if (e == null) { await p.setString('acct_email', email); guest = false; }
    return e;
  }
  static Future<String?> sendResetCode(String email) async {
    final p = await SharedPreferences.getInstance();
    return _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/recover'), headers: _h(false), body: jsonEncode({'email': email})), p, save: false);
  }
  /// Checks the emailed code, signs in, then sets the new password.
  static Future<String?> resetWithCode(String email, String code, String newPw) async {
    final p = await SharedPreferences.getInstance();
    final e = await _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/verify'), headers: _h(false), body: jsonEncode({'type': 'recovery', 'email': email, 'token': code})), p);
    if (e != null) return e;
    final e2 = await _authCall(http.put(Uri.parse('$_sbUrl/auth/v1/user'), headers: _h(), body: jsonEncode({'password': newPw})), p, save: false);
    if (e2 == null) await p.setString('acct_email', email);
    return e2;
  }
  static Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    try { await http.post(Uri.parse('$_sbUrl/auth/v1/logout'), headers: _h()).timeout(const Duration(seconds: 10)); } catch (e, st) { Health.log(e, st); }
    _token = null; uid = null; _tokAt = null;
    await p.remove('sb_rt'); await p.remove('acct_email'); await p.remove('auth_done');
  }

  static void _save(SharedPreferences p, dynamic j) {
    _tokAt = DateTime.now();
    _token = j['access_token'] as String?;
    uid = (j['user'] ?? {})['id'] as String?;
    final rt = j['refresh_token'] as String?;
    if (rt != null) p.setString('sb_rt', rt);
  }

  static Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$_sbUrl/rest/v1/$path'), headers: _h()).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception('${r.statusCode} ${r.body}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static String publicUrl(String path) => '$_sbUrl/storage/v1/object/public/stories/$path';

  static Future<bool> upload(String path, List<int> bytes, String mime) async {
    final r = await http.post(Uri.parse('$_sbUrl/storage/v1/object/stories/$path'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token', 'Content-Type': mime}, body: bytes).timeout(const Duration(seconds: 90));
    return r.statusCode < 300;
  }

  static Future<void> removeFile(String path) async {
    try { await http.delete(Uri.parse('$_sbUrl/storage/v1/object/stories/$path'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token'}).timeout(const Duration(seconds: 20)); } catch (e, st) { Health.log(e, st); }
  }

  static Future<bool> galUpload(String path, List<int> bytes, String mime) async {
    final r = await http.post(Uri.parse('$_sbUrl/storage/v1/object/gallery/$path'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token', 'Content-Type': mime}, body: bytes).timeout(const Duration(seconds: 90));
    return r.statusCode < 300;
  }

  /// Deletes every file this user stored (stories and gallery) through the Storage API, so nothing is left behind when the account goes.
  static Future<void> wipeMyFiles() async {
    final u = uid;
    if (u == null) return;
    for (final b in ['stories', 'gallery', 'dm']) {
      try {
        final r = await http.post(Uri.parse('$_sbUrl/storage/v1/object/list/$b'), headers: _h(), body: jsonEncode({'prefix': u, 'limit': 200})).timeout(const Duration(seconds: 20));
        if (r.statusCode != 200) continue;
        for (final o in (jsonDecode(r.body) as List)) {
          final n = (o as Map)['name']?.toString();
          if (n == null || n.isEmpty) continue;
          await http.delete(Uri.parse('$_sbUrl/storage/v1/object/$b/$u/$n'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token'}).timeout(const Duration(seconds: 20));
        }
      } catch (e, st) { Health.log(e, st); }
    }
  }
  static Future<void> galRemove(String path) async {
    try { await http.delete(Uri.parse('$_sbUrl/storage/v1/object/gallery/$path'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token'}).timeout(const Duration(seconds: 20)); } catch (e, st) { Health.log(e, st); }
  }

  /// Short-lived signed URL for a photo in the private gallery bucket.
  static Future<String?> galSigned(String path) async {
    try {
      final r = await http.post(Uri.parse('$_sbUrl/storage/v1/object/sign/gallery/$path'), headers: _h(), body: jsonEncode({'expiresIn': 3600})).timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) return null;
      final u = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['signedURL']?.toString();
      if (u == null) return null;
      return '$_sbUrl/storage/v1$u';
    } catch (_) { return null; }
  }

  static Future<bool> patch(String path, Map<String, dynamic> body) async {
    final r = await http.patch(Uri.parse('$_sbUrl/rest/v1/$path'), headers: _h(), body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    return r.statusCode < 300;
  }

  static Future<dynamic> rpc(String fn, [Map<String, dynamic>? args]) async {
    final r = await http.post(Uri.parse('$_sbUrl/rest/v1/rpc/$fn'), headers: _h(), body: jsonEncode(args ?? {})).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception('${r.statusCode}');
    final t = utf8.decode(r.bodyBytes);
    return t.isEmpty ? null : jsonDecode(t);
  }

  static Future<void> delete(String path) async {
    final r = await http.delete(Uri.parse('$_sbUrl/rest/v1/$path'), headers: _h()).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception('${r.statusCode}');
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool upsert = false}) async {
    final h = _h();
    if (upsert) h['Prefer'] = 'resolution=merge-duplicates,return=representation';
    else h['Prefer'] = 'return=representation';
    final r = await http.post(Uri.parse('$_sbUrl/rest/v1/$path'), headers: h, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    if (r.statusCode >= 300) throw Exception('${r.statusCode} ${utf8.decode(r.bodyBytes)}');
    final t = utf8.decode(r.bodyBytes);
    return t.isEmpty ? null : jsonDecode(t);
  }
}

String _bad(String s) {
  final t = s.toLowerCase();
  if (RegExp(r'(https?://|www\.|\.com|\.net|\.org|@|t\.me|wa\.me)').hasMatch(t)) return 'No links or @ handles in papyri.';
  if (RegExp(r'[0-9٠-٩]{6,}').hasMatch(s)) return 'No phone numbers.';
  return '';
}

// ---------------- Entry ----------------
class BottlesPage extends StatefulWidget {
  const BottlesPage({super.key});
  @override
  State<BottlesPage> createState() => _BottlesPageState();
}

class _BottlesPageState extends State<BottlesPage> with SingleTickerProviderStateMixin {
  bool ready = false, ageOk = false, busy = true, failed = false;
  String nick = '', lang = 'en';
  final nickC = TextEditingController();
  late AnimationController anim;

  @override
  void initState() {
    super.initState();
    anim = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _init();
  }

  @override
  void dispose() {
    anim.dispose();
    nickC.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    ageOk = p.getBool('b_age') ?? false;
    nick = p.getString('b_nick') ?? '';
    lang = p.getString('b_lang') ?? 'en';
    nickC.text = nick;
    if (!(ageOk && nick.isNotEmpty) && Passport.nickname.trim().length >= 2) {
      // First-run already confirmed 18+ and the nickname: join without asking again.
      final n = Passport.nickname.trim();
      if (await Sb.signIn()) {
        try {
          await Sb.post('profiles', {'id': Sb.uid, 'nick': n, 'lang': lang, 'age_ok': true}, upsert: true);
          await p.setBool('b_age', true); await p.setString('b_nick', n);
          ageOk = true; nick = n;
        } catch (_) { failed = true; }
      } else { failed = true; }
    } else if (ageOk && nick.isNotEmpty) {
      final ok = await Sb.signIn();
      if (!ok) failed = true; else { try { await Sb.post('profiles', {'id': Sb.uid, 'nick': nick, 'lang': lang, 'age_ok': true}, upsert: true); } catch (e, st) { Health.log(e, st); } }
    }
    if (mounted) setState(() { ready = ageOk && nick.isNotEmpty && !failed; busy = false; });
  }

  Future<void> _join(bool confirmed) async {
    final n = nickC.text.trim();
    if (!confirmed) { toast(context, 'Confirm you are 18 or older'); return; }
    if (n.length < 2 || n.length > 20) { toast(context, 'Nickname: 2 to 20 letters'); return; }
    setState(() { busy = true; failed = false; });
    final ok = await Sb.signIn();
    if (!ok) { if (mounted) setState(() { busy = false; failed = true; }); return; }
    try {
      await Sb.post('profiles', {'id': Sb.uid, 'nick': n, 'lang': lang, 'age_ok': true}, upsert: true);
      final p = await SharedPreferences.getInstance();
      await p.setBool('b_age', true);
      await p.setString('b_nick', n);
      await p.setString('b_lang', lang);
      if (mounted) setState(() { ready = true; busy = false; nick = n; });
    } catch (e) {
      if (mounted) { setState(() { busy = false; failed = true; }); toast(context, 'Could not join: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L('Papyrus • بردية')), backgroundColor: kBg),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ready ? _home() : _gate(),
    );
  }

  Widget _river() => SizedBox(
        height: 150,
        child: AnimatedBuilder(
          animation: anim,
          builder: (c, _) => CustomPaint(painter: _RiverPainter(anim.value), size: const Size(double.infinity, 150)),
        ),
      );

  Widget _gate() {
    bool conf = false;
    return StatefulBuilder(builder: (c, set) => ListView(padding: const EdgeInsets.all(16), children: [
      _river(),
      Text(L('Write a papyrus and watch it travel the world. Someone anywhere finds it.'), style: TextStyle(fontSize: 17, height: 1.4)),
      const SizedBox(height: 12),
      TextField(controller: nickC, maxLength: 20, decoration: InputDecoration(labelText: L('Nickname (not your real name)'), border: OutlineInputBorder())),
      DropdownButton<String>(
        value: lang,
        isExpanded: true,
        items: [for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(Ui.rtl ? 'أقرا البرديات بـ: ${kNames[i]}' : 'I read papyri in: ${kNames[i]}'))],
        onChanged: (v) => set(() => lang = v ?? 'en'),
      ),
      CheckboxListTile(value: conf, onChanged: (v) => set(() => conf = v ?? false), title: Text(L('I am 18+ and accept the rules (text only, no links or numbers, report and block)'), style: TextStyle(fontSize: 13))),
      if (failed) Text(L('Could not connect. Check internet and try again.'), style: TextStyle(color: Colors.orangeAccent)),
      FilledButton(onPressed: () => _join(conf), child: Text(L('Enter'))),
      const SizedBox(height: 10),
      Text(L('Anonymous accounts: if you are blocked or banned you could come back with a new one. Pattern filters miss tricks. Report anything wrong.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
    ]));
  }

  Widget _home() => ListView(padding: const EdgeInsets.all(16), children: [
        _river(),
        Text(Ui.rtl ? 'أهلاً $nick' : 'Hi $nick', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        _tile(Icons.send, 'Send a papyrus', 'Ask about a place, teach a phrase, or say hello', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThrowPage(lang: lang)))),
        _tile(Icons.search, 'Catch a papyrus', 'Pick one papyrus from someone else', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatchPage(lang: lang)))),
        _tile(Icons.inbox, 'My papyri', 'Replies and conversations', () => Navigator.push(context, MaterialPageRoute(builder: (_) => InboxPage(lang: lang)))),
        const SizedBox(height: 10),
        Text(L('18+ self-declared. Text only. No links or numbers. Report and block in every conversation.'), style: TextStyle(fontSize: 11, color: Colors.white38)),
      ]);

  Widget _tile(IconData i, String t, String s, VoidCallback f) => Card(
        color: const Color(0xFF12304D),
        child: ListTile(leading: Icon(i, color: kGreen), title: Text(t), subtitle: Text(s), trailing: const Icon(Icons.chevron_right), onTap: f),
      );
}

class _RiverPainter extends CustomPainter {
  final double t;
  _RiverPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final bg = Paint()..shader = const LinearGradient(colors: [Color(0xFF0E3A5C), Color(0xFF12304D)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Offset.zero & s);
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(18)), bg);
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(0, s.height * (0.45 + 0.15 * k));
      for (double x = 0; x <= s.width; x += 6) {
        final y = s.height * (0.45 + 0.15 * k) + 6 * (k + 1) * _sin(x / 40 + t * 6.2832 * (k + 1) / 2);
        path.lineTo(x, y);
      }
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withOpacity(0.12 + 0.05 * k));
    }
    final bx = s.width * ((t * 1.0) % 1.0);
    final by = s.height * 0.5 + 5 * _sin(t * 18);
    c.save();
    c.translate(bx, by);
    c.rotate(0.3 * _sin(t * 12));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -14, 18, 28), const Radius.circular(6)), Paint()..color = const Color(0xFF7FD6C9).withOpacity(0.85));
    c.drawRect(const Rect.fromLTWH(-3, -19, 6, 6), Paint()..color = kGreen);
    c.drawRect(const Rect.fromLTWH(-4, -4, 8, 10), Paint()..color = const Color(0xFFF2E6C9));
    c.restore();
  }

  double _sin(double x) => _sinImpl(x);
  @override
  bool shouldRepaint(covariant _RiverPainter o) => o.t != t;
}

double _sinImpl(double x) {
  // Taylor-free sine via dart:math-free approximation (Bhaskara), keeps file self-contained.
  const pi = 3.141592653589793;
  var v = x % (2 * pi);
  if (v < 0) v += 2 * pi;
  final neg = v > pi;
  if (neg) v -= pi;
  final r = 16 * v * (pi - v) / (5 * pi * pi - 4 * v * (pi - v));
  return neg ? -r : r;
}

// ---------------- Throw ----------------
class ThrowPage extends StatefulWidget {
  final String lang;
  const ThrowPage({super.key, required this.lang});
  @override
  State<ThrowPage> createState() => _ThrowPageState();
}

class _ThrowPageState extends State<ThrowPage> with SingleTickerProviderStateMixin {
  String kind = 'free', place = kDest[0][0] as String, writeLang = 'en';
  final c = TextEditingController();
  final focus = FocusNode();
  bool busy = false, flying = false;
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    Sb.gateOpen(context);
    c.addListener(() => SharedPreferences.getInstance().then((p) => c.text.isEmpty ? p.remove('draft_throw') : p.setString('draft_throw', c.text)));
    SharedPreferences.getInstance().then((p) async {
      if (await Sb.loadGuest()) return;
      final d = p.getString('draft_throw');
      if (d != null && d.isNotEmpty && c.text.isEmpty && mounted) c.text = d;
      if (!(p.getBool('rules_seen') ?? false)) {
        await p.setBool('rules_seen', true);
        if (mounted) _rules();
      } else if (mounted) { focus.requestFocus(); }
    });
  }

  @override
  void dispose() { c.dispose(); focus.dispose(); _fly.dispose(); super.dispose(); }

  void _rules() => showModalBottomSheet(context: context, backgroundColor: const Color(0xFF12304D), builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('Before you write • قبل ما تكتب'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kGreen)),
          const SizedBox(height: 10),
          Text(L('• Text only. No links, phone numbers or social handles.\n• Be kind. Never ask for or send money.\n• Someone anywhere may answer. Report and block if needed.'), style: TextStyle(height: 1.6)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(L('Got it • تمام')))),
        ]),
      )).then((_) { if (mounted) focus.requestFocus(); });

  final friend = TextEditingController();

  /// Writes a "two truths and a lie" papyrus into the text box. Format: first line = lie number, then three lines.
  Future<void> _twoTruths() async {
    final f = [TextEditingController(), TextEditingController(), TextEditingController()];
    var lie = 3;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Text(L('Two truths and a lie • حقيقتين وكذبة')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) Row(children: [
          Radio<int>(value: i + 1, groupValue: lie, onChanged: (v) => set(() => lie = v ?? lie)),
          Expanded(child: TextField(controller: f[i], maxLength: 90, decoration: InputDecoration(counterText: '', hintText: '${i + 1}'))),
        ]),
        Text(L('Select the circle next to your LIE. The reader guesses.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Cancel'))), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Use')))],
    )));
    if (ok != true) return;
    final lines = f.map((e) => e.text.trim().replaceAll('\n', ' ')).toList();
    if (lines.any((e) => e.length < 3)) { if (mounted) toast(context, 'Write all three lines.'); return; }
    setState(() => c.text = '🎭$lie\n${lines.join('\n')}');
  }
  Future<void> _send() async {
    if (await Sb.needAccount(context)) return;
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least a few words'); return; }
    final b = _bad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    if (!Passport.useInk()) { toast(context, 'Out of ink. New ink at 12:00, or solve the daily puzzle for +3.'); return; }
    setState(() => busy = true);
    try {
      try { await Sb.post('profiles', {'id': Sb.uid, 'nick': Passport.nickname.trim().length >= 2 ? Passport.nickname.trim() : 'Traveler', 'lang': writeLang, 'age_ok': true}, upsert: true); } catch (e, st) { Health.log(e, st); }
      final fc = friend.text.trim().toLowerCase();
      if (fc.isNotEmpty) {
        final ok = await Sb.rpc('send_direct', {'p_code': fc, 'p_kind': kind, 'p_place': kind == 'place' ? place : null, 'p_body': t, 'p_lang': writeLang});
        if (ok != true) throw Exception(L('No friend with that code, or you cannot send to them.'));
      } else {
        await Sb.post('bottles', {'author': Sb.uid, 'kind': kind, 'place': kind == 'place' ? place : null, 'body': t, 'lang': writeLang});
      }
      HapticFeedback.mediumImpact();
      SharedPreferences.getInstance().then((p) => p.remove('draft_throw'));
      focus.unfocus();
      if (mounted) setState(() => flying = true);
    } catch (e) {
      if (mounted) { setState(() { busy = false; flying = false; }); toast(context, L('Could not send. Check your connection and try again.')); }
    }
  }

  Future<void> _pickLang() async {
    final r = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF12304D), builder: (_) => ListView(children: [
      for (var i = 0; i < kCodes.length; i++) ListTile(title: Text(kNames[i]), trailing: writeLang == kCodes[i] ? const Icon(Icons.check, color: kGreen) : null, onTap: () => Navigator.pop(context, kCodes[i])),
    ]));
    if (r != null) setState(() => writeLang = r);
  }

  @override
  Widget build(BuildContext context) {
    final hints = {
      'place': 'Ask about this place. What should a first-time visitor know?',
      'phrase': 'Write a phrase you want to learn or hear in Arabic.',
      'free': 'Say hello. Tell a little about your day.',
    };
    final langName = kNames[kCodes.indexOf(writeLang).clamp(0, kNames.length - 1)];
    return Scaffold(
      backgroundColor: kBg,
      body: flying
          ? SendSequence(onDone: () { if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PapyrusTripPage())); })
          : SafeArea(
        child: Stack(children: [
          Opacity(
            opacity: 1,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  ActionChip(avatar: const Icon(Icons.translate, size: 16), label: Text(langName), onPressed: _pickLang),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.info_outline, size: 20, color: Colors.white54), onPressed: _rules),
                ]),
              ),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
                  for (final k in [['free', 'Hello • أهلا'], ['place', 'About a place • مكان'], ['phrase', 'Phrase • جملة']])
                    Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(k[1]), selected: kind == k[0], onSelected: (_) => setState(() => kind = k[0]))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: Align(alignment: AlignmentDirectional.centerStart, child: ActionChip(avatar: const Text('🎭'), label: Text(L('Two truths and a lie • حقيقتين وكذبة')), onPressed: _twoTruths)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: TextField(controller: friend, maxLength: 12, autocorrect: false, decoration: InputDecoration(counterText: '', isDense: true, prefixIcon: const Icon(Icons.person_add_alt, size: 18), hintText: L('Friend\'s Nilo code (optional, sends only to them)'))),
              ),
              if (kind == 'place')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: DropdownButton<String>(
                    value: place, isExpanded: true,
                    items: [for (final d in kDest) DropdownMenuItem(value: d[0] as String, child: Text(d[0] as String))],
                    onChanged: (v) => setState(() => place = v ?? place),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    controller: c, focusNode: focus, maxLines: null, expands: true, maxLength: 300,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 22, height: 1.5),
                    decoration: InputDecoration(border: InputBorder.none, hintText: hints[kind], hintStyle: const TextStyle(color: Colors.white38, fontSize: 20), counterStyle: const TextStyle(color: Colors.white38)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  width: double.infinity, height: 54,
                  child: FilledButton.icon(
                    onPressed: busy ? null : _send,
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                    label: Text(L('Send into the Nile • ابعتها في النيل'), style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Catch ----------------
class CatchPage extends StatefulWidget {
  final String lang;
  const CatchPage({super.key, required this.lang});
  @override
  State<CatchPage> createState() => _CatchPageState();
}

class _CatchPageState extends State<CatchPage> {
  bool busy = false, done = false;
  String err = '';

  Future<void> _catch() async {
    if (Passport.catchesLeft <= 0) { setState(() => err = 'You caught your 10 papyri for now. A new batch arrives at 12:00.'); return; }
    setState(() { busy = true; err = ''; });
    try {
      final r = await http.post(Uri.parse('$_sbUrl/rest/v1/rpc/catch_bottle'), headers: {'apikey': _sbKey, 'Content-Type': 'application/json', 'Authorization': 'Bearer ${Sb._token}'}, body: '{}').timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300) throw Exception('${r.statusCode} ${r.body}');
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (!mounted) return;
      if (j == null || (j is Map && j['id'] == null)) {
        setState(() { busy = false; done = true; });
      } else {
        setState(() => busy = false);
        Passport.useCatch();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ThreadPage(bottle: Map<String, dynamic>.from(j as Map), lang: widget.lang)));
      }
    } catch (e) {
      if (mounted) setState(() { busy = false; err = 'Could not catch: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Catch a papyrus')), backgroundColor: kBg),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.water, size: 72, color: kGreen),
            const SizedBox(height: 12),
            Text(done ? 'No papyri are travelling right now. Send one, and check back later.' : 'A random papyrus from someone else will arrive. You can reply, report or block.', textAlign: TextAlign.center),
            if (err.isNotEmpty) Text(L(err), style: TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : _catch, child: busy ? CircularProgressIndicator() : Text(Ui.rtl ? 'دوّر على بردية (فاضل ${Passport.catchesLeft} النهارده)' : 'Look for a papyrus (${Passport.catchesLeft} left today)')),
          ]),
        ),
      );
}

// ---------------- Inbox ----------------
class InboxPage extends StatefulWidget {
  final String lang;
  const InboxPage({super.key, required this.lang});
  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<dynamic> l = [];
  bool busy = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Sb.get('bottles?select=*,replies(id,author)&order=created_at.desc&limit=50');
      if (mounted) setState(() { l = r as List; busy = false; });
      Health.markSeen(r as List);
    } catch (e) {
      if (mounted) setState(() { busy = false; err = '$e'; });
    }
  }

  String _ago(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return L('just now');
    if (m < 60) return '$m ${L('min ago')}';
    if (m < 1440) return '${m ~/ 60} ${L('h ago')}';
    return '${m ~/ 1440} ${L('d ago')}';
  }

  Widget _tile(Map b) {
    final mine = b['author'] == Sb.uid;
    final reps = ((b['replies'] ?? []) as List);
    final theirs = reps.where((r) => (r as Map)['author'] != Sb.uid).length;
    String st; Color col;
    if (b['status'] == 'closed') { st = L('Closed'); col = Colors.white38; }
    else if (theirs > 0) { st = '${L('Replied')} ($theirs)'; col = kGreen; }
    else if (mine && b['catcher'] == null) { st = L('Floating: nobody caught it yet'); col = Colors.amberAccent; }
    else if (mine) { st = L('Caught by someone'); col = Colors.lightBlueAccent; }
    else { st = reps.isEmpty ? L('You caught it: write back') : L('You caught it'); col = Colors.lightBlueAccent; }
    return ListTile(
      leading: Icon(mine ? Icons.send : Icons.download, color: kGreen),
      title: Text((b['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${mine ? L('Sent by you') : L('Caught by you')} • ${_ago(b['created_at']?.toString())}${b['place'] != null ? ' • ${b['place']}' : ''}\n$st', style: TextStyle(color: col)),
      isThreeLine: true,
      onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadPage(bottle: Map<String, dynamic>.from(b), lang: widget.lang))); _load(); },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('My papyri')), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : err.isNotEmpty
                ? Center(child: Text(L(err)))
                : l.isEmpty
                    ? Center(child: Text(L('Nothing yet. Send or catch a papyrus.')))
                    : RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        for (final b in l) _tile(b as Map),
                      ])),
      );
}

// ---------------- Thread ----------------
class ThreadPage extends StatefulWidget {
  final Map<String, dynamic> bottle;
  final String lang;
  const ThreadPage({super.key, required this.bottle, required this.lang});
  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  List<dynamic> replies = [];
  final c = TextEditingController();
  String err = '';
  final Map<String, String> tr = {};
  bool auto = false, _autoBusy = false;

  String get bid => widget.bottle['id'].toString();

  Future<void> _journey() async {
    String from = '', to = '';
    try {
      final r = await Sb.rpc('bottle_journey', {'p_id': bid}) as List;
      if (r.isNotEmpty) { from = (r.first['from_cc'] ?? '').toString(); to = (r.first['to_cc'] ?? '').toString(); }
    } catch (e, st) { Health.log(e, st); }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => JourneyPage(fromCc: from, toCc: to)));
  }
  String get other => (widget.bottle['author'] == Sb.uid ? widget.bottle['catcher'] : widget.bottle['author'])?.toString() ?? '';

  Timer? _poll;
  Map<String, dynamic> _prof = {};
  bool _profTried = false;

  /// Other person's own profile photo/avatar, shown only once both sides have written in the thread.
  bool get _bothWrote => replies.any((r) => (r as Map)['author'] == Sb.uid) && (widget.bottle['author'] != Sb.uid || replies.any((r) => (r as Map)['author'] != Sb.uid)) && other.isNotEmpty;

  Future<void> _loadProf() async {
    if (_profTried || !_bothWrote) return;
    _profTried = true;
    try {
      final r = await Sb.rpc('get_profile', {'p_uid': other});
      if (r is List && r.isNotEmpty && mounted) setState(() => _prof = Map<String, dynamic>.from(r.first as Map));
    } catch (_) { _profTried = false; }
  }

  void _openProf() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PeerProfilePage(uid: other, prof: _prof, bid: bid, otherIsAuthor: widget.bottle['author'] != Sb.uid)));
  }

  Future<void> _deleteMine() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(L('Delete this papyrus?')),
      content: Text(L('The papyrus and all its replies are deleted for both of you. This cannot be undone.')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Cancel'))), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Delete')))],
    ));
    if (ok != true) return;
    try {
      await Sb.rpc('delete_my_bottle', {'p_id': bid});
      if (mounted) { toast(context, L('Deleted.')); Navigator.pop(context); }
    } catch (_) { if (mounted) toast(context, L('Could not delete. Try again.')); }
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) { auto = p.getBool('auto_tr') ?? false; _load(); });
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() { _poll?.cancel(); c.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await Sb.get('replies?bottle_id=eq.$bid&order=created_at.asc');
      if (mounted) setState(() { replies = r as List; err = ''; });
      _loadProf();
      if (auto) _autoTranslate();
    } catch (e) {
      if (mounted && replies.isEmpty) setState(() => err = L('Could not load the messages. Check your connection.'));
    }
  }

  /// Language bridge: translates what the other person wrote into the reader's language, newest 12 messages, one at a time.
  Future<void> _autoTranslate() async {
    if (_autoBusy) return;
    _autoBusy = true;
    try {
      final items = <List<String>>[];
      if (widget.bottle['author'] != Sb.uid) items.add(['b', (widget.bottle['body'] ?? '').toString()]);
      for (final r in replies.reversed.take(12).toList().reversed) { if ((r as Map)['author'] != Sb.uid) items.add([r['id'].toString(), (r['body'] ?? '').toString()]); }
      for (final it in items) {
        if (!mounted || !auto) break;
        if (tr[it[0]] != null || it[1].trim().isEmpty) continue;
        final r = await trText(it[1], 'auto', widget.lang);
        if (!mounted) break;
        if (r.ok) { setState(() => tr[it[0]] = r.translation); } else { break; }
      }
    } finally { _autoBusy = false; }
  }

  Future<void> _wordSwap() async {
    final w = TextEditingController(), m = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(L('Word swap • تبادل كلمة')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: w, maxLength: 30, decoration: InputDecoration(counterText: '', hintText: L('A word from your language'))),
        TextField(controller: m, maxLength: 60, decoration: InputDecoration(counterText: '', hintText: L('What it means'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Cancel'))), TextButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Use')))],
    ));
    if (ok != true) return;
    final a = w.text.trim().replaceAll('=', ' '), b = m.text.trim();
    if (a.isEmpty || b.isEmpty) return;
    setState(() => c.text = '🔤 $a = $b');
  }

  Future<void> _toggleAuto() async {
    final p = await SharedPreferences.getInstance();
    setState(() => auto = !auto);
    await p.setBool('auto_tr', auto);
    if (auto) { _autoTranslate(); toast(context, L('Language bridge on: messages are translated for you.')); }
  }

  Future<void> _send() async {
    if (await Sb.needAccount(context)) return;
    final t = c.text.trim();
    if (t.isEmpty) return;
    final b = _bad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    try {
      await Sb.post('replies', {'bottle_id': bid, 'author': Sb.uid, 'body': t});
      Passport.addInk(1);
      c.clear();
      await _load();
    } catch (e) {
      if (mounted) toast(context, L('Could not send. Check your connection and try again.'));
    }
  }

  Future<void> _translate(String key, String text) async {
    final r = await trText(text, 'auto', widget.lang);
    if (!mounted) return;
    if (r.ok) setState(() => tr[key] = r.translation);
    else toast(context, r.error.isEmpty ? 'Translation failed' : r.error);
  }

  Future<void> _report() async {
    final reasons = ['Asked for money', 'Asked for contact details', 'Sexual or inappropriate', 'Says they are under 18', 'Hate or threats', 'Other'];
    final pick = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: Text(L('Report this conversation')), children: [for (final r in reasons) SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r))]));
    if (pick == null) return;
    try {
      await Sb.post('reports', {'reporter': Sb.uid, 'bottle_id': bid, 'reason': pick});
      if (mounted) toast(context, 'Reported. You can also block this person.');
    } catch (e) {
      if (mounted) toast(context, 'Could not report: $e');
    }
  }

  Future<void> _block() async {
    if (other.isEmpty) return;
    try {
      await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': other}, upsert: true);
      await http.post(Uri.parse('$_sbUrl/rest/v1/rpc/close_bottle'), headers: {'apikey': _sbKey, 'Content-Type': 'application/json', 'Authorization': 'Bearer ${Sb._token}'}, body: jsonEncode({'p_id': bid}));
      if (mounted) { toast(context, 'Blocked. You will not meet them again.'); Navigator.pop(context); }
    } catch (e) {
      if (mounted) toast(context, 'Could not block: $e');
    }
  }

  final Map<String, int> _guess = {};

  Widget _truthCard(String key, String text, bool mine) {
    final ls = text.split('\n');
    final lie = int.tryParse(ls[0].substring(2).trim()) ?? 0;
    final g = _guess[key];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(L('🎭 Two truths and a lie • حقيقتين وكذبة'), style: const TextStyle(fontWeight: FontWeight.w800, color: kGreen)),
      for (var i = 1; i <= 3; i++) Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          onTap: (mine || g != null) ? null : () => setState(() => _guess[key] = i),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: (g != null || mine) && i == lie ? Colors.redAccent : Colors.white24)),
            child: Text('$i. ${ls[i]}${(g != null || mine) && i == lie ? '   ❌ ${L('the lie')}' : ''}'),
          ),
        ),
      ),
      if (g != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(g == lie ? L('You got it! • صح!') : L('Not this time. • مش المرة دي.'), style: const TextStyle(fontWeight: FontWeight.w700))),
      if (!mine && g == null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(L('Tap the line you think is the lie.'), style: const TextStyle(fontSize: 11, color: Colors.white54))),
    ]);
  }

  Widget _msg(String key, String text, bool mine) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(color: mine ? const Color(0xFF1C4A6E) : const Color(0xFF12304D), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine && _prof.isNotEmpty) InkWell(onTap: _openProf, child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [
              AvatarView(avatar: (_prof['avatar'] ?? '').toString(), path: (_prof['avatar_path'] ?? '').toString(), size: 24),
              const SizedBox(width: 6),
              Flexible(child: Text(((_prof['nick'] ?? '').toString().isEmpty ? L('Papyrus friend') : _prof['nick'].toString()) + ((_prof['gender'] ?? '').toString().isEmpty ? '' : ' ' + Gender.icon(_prof['gender'].toString())), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen))),
            ]))),
            if (text.startsWith('🎭') && text.split('\n').length == 4) _truthCard(key, text, mine) else Text(text),
            if (text.startsWith('🔤 ') && text.contains(' = ') && !mine) Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(
              onPressed: () async { final i = text.indexOf(' = '); await saveWord(text.substring(3, i), text.substring(i + 3)); if (mounted) toast(context, L('Saved to your word book.')); },
              icon: const Icon(Icons.bookmark_add_outlined, size: 16), label: Text(L('Save to my word book')))),
            if (tr[key] != null) Text(tr[key]!, style: const TextStyle(color: kGreen)),
            if (!mine && tr[key] == null) InkWell(onTap: () => _translate(key, text), child: Padding(padding: EdgeInsets.only(top: 6), child: Text(L('Translate (machine, may be wrong)'), style: TextStyle(fontSize: 12, color: Colors.white54)))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.bottle;
    final closed = b['status'] == 'closed';
    final waiting = b['catcher'] == null && b['author'] == Sb.uid;
    return Scaffold(
      appBar: AppBar(title: Row(children: [if (_prof.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 10), child: AvatarView(avatar: (_prof['avatar'] ?? '').toString(), path: (_prof['avatar_path'] ?? '').toString(), size: 34)), Flexible(child: Text(b['kind'] == 'place' ? 'About ${b['place']}' : 'Papyrus', overflow: TextOverflow.ellipsis)), if ((_prof['gender'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(left: 8), child: Text(Gender.icon(_prof['gender'].toString()), style: const TextStyle(fontSize: 18)))]), backgroundColor: kBg, actions: [
        if (b['author'] == Sb.uid) IconButton(icon: const Icon(Icons.delete_outline), tooltip: L('Delete'), onPressed: _deleteMine),
        IconButton(icon: Icon(Icons.translate, color: auto ? kGreen : Colors.white54), tooltip: L('Language bridge'), onPressed: _toggleAuto),
        IconButton(icon: const Icon(Icons.public), tooltip: L('Journey'), onPressed: _journey),
        IconButton(icon: Icon(Icons.flag_outlined), tooltip: L('Report'), onPressed: _report),
        IconButton(icon: Icon(Icons.block), tooltip: L('Block'), onPressed: _block),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            _msg('b', (b['body'] ?? '').toString(), b['author'] == Sb.uid),
            for (final r in replies) _msg(r['id'].toString(), (r['body'] ?? '').toString(), r['author'] == Sb.uid),
            if (err.isNotEmpty) Row(children: [Expanded(child: Text(err, style: const TextStyle(color: Colors.white70))), TextButton(onPressed: _load, child: Text(L('Retry')))]),
            Padding(padding: EdgeInsets.all(8), child: Text(L('Safety: never send money or ID details. Meet only in public places. Report anything wrong.'), style: TextStyle(fontSize: 11, color: Colors.white38))),
          ]),
        ),
        if (waiting)
          Padding(padding: const EdgeInsets.all(14), child: Text(L('Waiting for someone to catch your papyrus. Replies will appear here.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)))
        else if (!closed)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: c, maxLength: 400, decoration: InputDecoration(hintText: L('Write a reply (text only, no links or numbers)'), counterText: '', border: OutlineInputBorder()))),
              IconButton(icon: const Text('🔤', style: TextStyle(fontSize: 22)), tooltip: L('Word swap'), onPressed: _wordSwap),
              IconButton(icon: const Icon(Icons.send, color: kGreen), onPressed: _send),
            ]),
          )
        else
          Padding(padding: EdgeInsets.all(12), child: Text(L('This conversation is closed.'))),
      ]),
    );
  }
}

/// Public wrapper so other screens use the same no-links / no-phone-number check as papyri.
String niloBad(String s) => _bad(s);


/// Full profile of the person on the other side of a papyrus. Only fields the server already returns (nick, bio, avatar, gender) plus the country from the papyrus route.
class PeerProfilePage extends StatefulWidget {
  final String uid, bid;
  final Map<String, dynamic> prof;
  final bool otherIsAuthor;
  const PeerProfilePage({super.key, required this.uid, required this.prof, required this.bid, required this.otherIsAuthor});
  @override
  State<PeerProfilePage> createState() => _PeerProfilePageState();
}

class _PeerProfilePageState extends State<PeerProfilePage> {
  String cc = '';
  bool? friend;
  List<dynamic> stories = [];
  bool storiesDone = false;
  bool addBusy = false;

  Future<void> _addFriend() async {
    setState(() => addBusy = true);
    String m;
    try {
      final r = (await Sb.rpc('request_friend_uid', {'p_uid': widget.uid})).toString();
      if (r == 'accepted') { m = L('You are now friends.'); if (mounted) setState(() => friend = true); }
      else if (r == 'sent') m = L('Friend request sent.');
      else if (r == 'age') m = L('Friend requests need the 18+ confirmation in your profile.');
      else m = L('Could not send the request.');
    } catch (_) { m = L('Could not send the request. Check your connection.'); }
    if (mounted) { toast(context, m); setState(() => addBusy = false); }
  }

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      final r = await Sb.rpc('bottle_journey', {'p_id': widget.bid}) as List;
      if (r.isNotEmpty && mounted) setState(() => cc = (r.first[widget.otherIsAuthor ? 'from_cc' : 'to_cc'] ?? '').toString());
    } catch (e, st) { Health.log(e, st); }
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      final r = await Sb.get('stories?select=id,body,mood,media_path,media_type,created_at&author=eq.${widget.uid}&created_at=gte.$since&order=created_at.desc&limit=20');
      if (mounted) setState(() { stories = r as List; storiesDone = true; });
    } catch (_) { if (mounted) setState(() => storiesDone = true); }
    try {
      final ids = ((await Sb.rpc('friend_ids')) as List?)?.map((e) => e.toString()).toList() ?? [];
      if (mounted) setState(() => friend = ids.contains(widget.uid));
    } catch (e, st) { Health.log(e, st); }
  }

  String _flag(String c) => c.length == 2 ? String.fromCharCodes(c.toUpperCase().codeUnits.map((x) => 0x1F1E6 + x - 65)) : '';

  @override
  Widget build(BuildContext context) {
    final p = widget.prof;
    final nick = (p['nick'] ?? '').toString().isEmpty ? L('Papyrus friend') : p['nick'].toString();
    final bio = (p['bio'] ?? '').toString();
    final g = (p['gender'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(L('Profile')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: AvatarView(avatar: (p['avatar'] ?? '').toString(), path: (p['avatar_path'] ?? '').toString(), size: 120)),
        const SizedBox(height: 12),
        Center(child: Text(nick, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
          if (cc.length == 2) Chip(label: Text('${_flag(cc)}  ${cc.toUpperCase()}')),
          if (g.isNotEmpty) Chip(label: Text('${Gender.icon(g)}  ${Gender.label(g)}')),
          if (friend == true) Chip(label: Text(L('Friend'))),
        ]),
        const SizedBox(height: 16),
        Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(14), child: Text(bio.isEmpty ? L('No bio yet.') : bio, style: TextStyle(height: 1.5, color: bio.isEmpty ? Colors.white54 : Colors.white)))),
        const SizedBox(height: 8),
        Text(L('Country is the papyrus route only. No city, no exact location, no contact details are stored or shown.'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(height: 16),
        PeerGallery(uid: widget.uid),
        const SizedBox(height: 16),
        Text(L('Stories (last 24 hours)'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (storiesDone && stories.isEmpty) Text(L('No public stories right now.'), style: const TextStyle(color: Colors.white54)),
        for (final st in stories) Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (st['media_path'] != null && st['media_type'] != 'video') Padding(padding: const EdgeInsets.only(bottom: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(Sb.publicUrl(st['media_path'].toString()), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
          if (st['media_path'] != null && st['media_type'] == 'video') Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(L('Video clip, open it in Stories.'), style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Text(((st['mood'] ?? '').toString().isEmpty ? '' : '${st['mood']} ') + (st['body'] ?? '').toString(), style: const TextStyle(height: 1.4)),
        ]))),
        const SizedBox(height: 16),
        if (friend == true) FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DmPage(uid: widget.uid, nick: nick))), icon: const Icon(Icons.chat_bubble_outline), label: Text(L('Message')))
        else if (friend == false) ...[
          FilledButton.icon(onPressed: addBusy ? null : _addFriend, icon: const Icon(Icons.person_add_alt_1), label: Text(L('Add friend'))),
          const SizedBox(height: 6),
          Text(L('They get a request and must accept. Until then no chat.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        Center(child: TextButton(onPressed: () async { try { await Sb.rpc('report_profile', {'p_uid': widget.uid}); if (mounted) toast(context, L('Reported. Thank you.')); } catch (_) { if (mounted) toast(context, L('Did not work. Try again.')); } }, child: Text(L('Report this profile'), style: const TextStyle(fontSize: 12)))),
      ]),
    );
  }
}

/// Exposed so unit tests can check the safety filter.
String papyrusFilterForTest(String s) => _bad(s);
