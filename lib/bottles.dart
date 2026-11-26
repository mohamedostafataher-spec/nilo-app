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

const _sbUrl = 'https://fbfvjihrbzsqlwmoejiq.supabase.co';
const _sbKey = 'sb_publishable_3Gw07lMxemop4QhYpgUszw_8jlkb5JP';

/// Minimal Supabase REST client (anonymous sign-in + RLS-protected tables).
class Sb {
  static String? _token;
  static String? uid;

  static Map<String, String> _h([bool auth = true]) => {
        'apikey': _sbKey,
        'Content-Type': 'application/json',
        if (auth && _token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<bool> signIn() async {
    final p = await SharedPreferences.getInstance();
    final rt = p.getString('sb_rt');
    if (rt != null) {
      try {
        final r = await http.post(Uri.parse('$_sbUrl/auth/v1/token?grant_type=refresh_token'), headers: _h(false), body: jsonEncode({'refresh_token': rt})).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200) {
          _save(p, jsonDecode(r.body));
          return true;
        }
      } catch (_) {}
    }
    try {
      final r = await http.post(Uri.parse('$_sbUrl/auth/v1/signup'), headers: _h(false), body: jsonEncode({'data': {}})).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        _save(p, jsonDecode(r.body));
        return true;
      }
    } catch (_) {}
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
  /// Create account: upgrades the current anonymous user (keeps your papyri) to an email account.
  static Future<String?> signUp(String email, String pw) async {
    final p = await SharedPreferences.getInstance();
    if (!await signIn()) return 'No connection';
    final e = await _authCall(http.put(Uri.parse('$_sbUrl/auth/v1/user'), headers: _h(), body: jsonEncode({'email': email, 'password': pw})), p, save: false);
    if (e == null) await p.setString('acct_email', email);
    return e;
  }
  static Future<String?> signInPassword(String email, String pw) async {
    final p = await SharedPreferences.getInstance();
    final e = await _authCall(http.post(Uri.parse('$_sbUrl/auth/v1/token?grant_type=password'), headers: _h(false), body: jsonEncode({'email': email, 'password': pw})), p);
    if (e == null) await p.setString('acct_email', email);
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
    try { await http.post(Uri.parse('$_sbUrl/auth/v1/logout'), headers: _h()).timeout(const Duration(seconds: 10)); } catch (_) {}
    _token = null; uid = null;
    await p.remove('sb_rt'); await p.remove('acct_email'); await p.remove('auth_done');
  }

  static void _save(SharedPreferences p, dynamic j) {
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
    try { await http.delete(Uri.parse('$_sbUrl/storage/v1/object/stories/$path'), headers: {'apikey': _sbKey, 'Authorization': 'Bearer $_token'}).timeout(const Duration(seconds: 20)); } catch (_) {}
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
      if (!ok) failed = true;
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
      appBar: AppBar(title: const Text('Papyrus • بردية'), backgroundColor: kBg),
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
      const Text('Write a papyrus and watch it travel the world. Someone anywhere finds it.', style: TextStyle(fontSize: 17, height: 1.4)),
      const SizedBox(height: 12),
      TextField(controller: nickC, maxLength: 20, decoration: const InputDecoration(labelText: 'Nickname (not your real name)', border: OutlineInputBorder())),
      DropdownButton<String>(
        value: lang,
        isExpanded: true,
        items: [for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text('I read papyri in: ${kNames[i]}'))],
        onChanged: (v) => set(() => lang = v ?? 'en'),
      ),
      CheckboxListTile(value: conf, onChanged: (v) => set(() => conf = v ?? false), title: const Text('I am 18+ and accept the rules (text only, no links or numbers, report and block)', style: TextStyle(fontSize: 13))),
      if (failed) const Text('Could not connect. Check internet and try again.', style: TextStyle(color: Colors.orangeAccent)),
      FilledButton(onPressed: () => _join(conf), child: const Text('Enter')),
      const SizedBox(height: 10),
      const Text('Anonymous accounts: if you are blocked or banned you could come back with a new one. Pattern filters miss tricks. Report anything wrong.', style: TextStyle(fontSize: 11, color: Colors.white38)),
    ]));
  }

  Widget _home() => ListView(padding: const EdgeInsets.all(16), children: [
        _river(),
        Text('Hi $nick', style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        _tile(Icons.send, 'Send a papyrus', 'Ask about a place, teach a phrase, or say hello', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThrowPage(lang: lang)))),
        _tile(Icons.search, 'Catch a papyrus', 'Pick one papyrus from someone else', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatchPage(lang: lang)))),
        _tile(Icons.inbox, 'My papyri', 'Replies and conversations', () => Navigator.push(context, MaterialPageRoute(builder: (_) => InboxPage(lang: lang)))),
        const SizedBox(height: 10),
        const Text('18+ self-declared. Text only. No links or numbers. Report and block in every conversation.', style: TextStyle(fontSize: 11, color: Colors.white38)),
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
    SharedPreferences.getInstance().then((p) async {
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
          const Text('Before you write • قبل ما تكتب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kGreen)),
          const SizedBox(height: 10),
          const Text('• Text only. No links, phone numbers or social handles.\n• Be kind. Never ask for or send money.\n• Someone anywhere may answer. Report and block if needed.', style: TextStyle(height: 1.6)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it • تمام'))),
        ]),
      )).then((_) { if (mounted) focus.requestFocus(); });

  Future<void> _send() async {
    final t = c.text.trim();
    if (t.length < 3) { toast(context, 'Write at least a few words'); return; }
    final b = _bad(t);
    if (b.isNotEmpty) { toast(context, b); return; }
    if (!Passport.useInk()) { toast(context, 'Out of ink. New ink at 12:00, or solve the daily puzzle for +3.'); return; }
    setState(() => busy = true);
    try {
      await Sb.post('bottles', {'author': Sb.uid, 'kind': kind, 'place': kind == 'place' ? place : null, 'body': t, 'lang': writeLang});
      HapticFeedback.mediumImpact();
      focus.unfocus();
      setState(() => flying = true);
      await _fly.forward();
      if (mounted) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PapyrusTripPage())); }
    } catch (e) {
      if (mounted) { setState(() { busy = false; flying = false; }); toast(context, 'Could not send: $e'); }
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
      body: SafeArea(
        child: Stack(children: [
          AnimatedBuilder(
            animation: _fly,
            builder: (_, child) => Opacity(opacity: 1 - _fly.value, child: Transform.translate(offset: Offset(0, -380 * _fly.value), child: Transform.scale(scale: 1 - 0.7 * _fly.value, child: child))),
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
                    label: const Text('Send into the Nile • ابعتها في النيل', style: TextStyle(fontSize: 16)),
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
        appBar: AppBar(title: const Text('Catch a papyrus'), backgroundColor: kBg),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.water, size: 72, color: kGreen),
            const SizedBox(height: 12),
            Text(done ? 'No papyri are travelling right now. Send one, and check back later.' : 'A random papyrus from someone else will arrive. You can reply, report or block.', textAlign: TextAlign.center),
            if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : _catch, child: busy ? const CircularProgressIndicator() : Text('Look for a papyrus (${Passport.catchesLeft} left today)')),
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
      final r = await Sb.get('bottles?select=*&order=created_at.desc&limit=50');
      if (mounted) setState(() { l = r as List; busy = false; });
    } catch (e) {
      if (mounted) setState(() { busy = false; err = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My papyri'), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : err.isNotEmpty
                ? Center(child: Text(err))
                : l.isEmpty
                    ? const Center(child: Text('Nothing yet. Send or catch a papyrus.'))
                    : ListView(children: [
                        for (final b in l)
                          ListTile(
                            leading: Icon(b['author'] == Sb.uid ? Icons.send : Icons.download, color: kGreen),
                            title: Text((b['body'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${b['kind']}${b['place'] != null ? ' • ${b['place']}' : ''} • ${b['status']}'),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThreadPage(bottle: Map<String, dynamic>.from(b as Map), lang: widget.lang))),
                          ),
                      ]),
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

  String get bid => widget.bottle['id'].toString();
  String get other => (widget.bottle['author'] == Sb.uid ? widget.bottle['catcher'] : widget.bottle['author'])?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Sb.get('replies?bottle_id=eq.$bid&order=created_at.asc');
      if (mounted) setState(() => replies = r as List);
    } catch (e) {
      if (mounted) setState(() => err = '$e');
    }
  }

  Future<void> _send() async {
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
      if (mounted) toast(context, 'Could not send: $e');
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
    final pick = await showDialog<String>(context: context, builder: (c) => SimpleDialog(title: const Text('Report this conversation'), children: [for (final r in reasons) SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r))]));
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

  Widget _msg(String key, String text, bool mine) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(color: mine ? const Color(0xFF1C4A6E) : const Color(0xFF12304D), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text),
            if (tr[key] != null) Text(tr[key]!, style: const TextStyle(color: kGreen)),
            if (!mine && tr[key] == null) InkWell(onTap: () => _translate(key, text), child: const Padding(padding: EdgeInsets.only(top: 6), child: Text('Translate (machine, may be wrong)', style: TextStyle(fontSize: 12, color: Colors.white54)))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.bottle;
    final closed = b['status'] == 'closed';
    return Scaffold(
      appBar: AppBar(title: Text(b['kind'] == 'place' ? 'About ${b['place']}' : 'Papyrus'), backgroundColor: kBg, actions: [
        IconButton(icon: const Icon(Icons.flag_outlined), tooltip: 'Report', onPressed: _report),
        IconButton(icon: const Icon(Icons.block), tooltip: 'Block', onPressed: _block),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            _msg('b', (b['body'] ?? '').toString(), b['author'] == Sb.uid),
            for (final r in replies) _msg(r['id'].toString(), (r['body'] ?? '').toString(), r['author'] == Sb.uid),
            if (err.isNotEmpty) Text(err),
            const Padding(padding: EdgeInsets.all(8), child: Text('Safety: never send money or ID details. Meet only in public places. Report anything wrong.', style: TextStyle(fontSize: 11, color: Colors.white38))),
          ]),
        ),
        if (!closed)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: c, maxLength: 400, decoration: const InputDecoration(hintText: 'Write a reply (text only, no links or numbers)', counterText: '', border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.send, color: kGreen), onPressed: _send),
            ]),
          )
        else
          const Padding(padding: EdgeInsets.all(12), child: Text('This conversation is closed.')),
      ]),
    );
  }
}
