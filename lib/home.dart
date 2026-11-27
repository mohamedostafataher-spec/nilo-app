import 'health.dart';
import 'cache.dart';
import 'i18n.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'extras.dart';
import 'world.dart';
import 'net.dart';
import 'bottles.dart';
import 'screens.dart';
import 'stories.dart';
import 'navbar.dart';
import 'today.dart';
import 'circles.dart';
import 'letters.dart';
import 'globe.dart';
import 'games.dart';
import 'places.dart';

/// Main shell: one living Nile scene + simple bottom nav.
class TouristHome extends StatefulWidget {
  const TouristHome({super.key});
  @override
  State<TouristHome> createState() => _TouristHomeState();
}

class _TouristHomeState extends State<TouristHome> {
  int tab = 0;
  int hub = 0; // stories hub: 0 story, 1 stories, 2 circles, 3 place letters

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { Health.offerUpdate(context); Health.refreshUnread(); } });
  }

  Future<void> _send() async {
    final p = await SharedPreferences.getInstance();
    final joined = (p.getBool('b_age') ?? false) && (p.getString('b_nick') ?? '').isNotEmpty;
    if (!mounted) return;
    if (!joined) { Navigator.of(context).push(niloRoute(const BottlesPage())); return; }
    final lang = p.getString('b_lang') ?? 'en';
    final ok = await Sb.signIn();
    if (!mounted) return;
    if (!ok) { toast(context, 'No connection. Try again.'); return; }
    Navigator.of(context).push(niloRoute(ThrowPage(lang: lang)));
  }

  Widget _hub() => Column(children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(children: [
              for (final e in const [[0, 'Tale • حكاية'], [1, 'Stories • قصص'], [2, 'Circles • دوائر'], [3, 'Letters • خطابات']].map((x) => x))
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => hub = e[0] as int),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: hub == e[0] ? kGreen.withOpacity(0.22) : Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: hub == e[0] ? kGreen : Colors.transparent),
                      ),
                      child: Center(child: Text(L(e[1] as String), style: TextStyle(fontWeight: FontWeight.w700, color: hub == e[0] ? kGreen : Colors.white60))),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        Expanded(child: hub == 0 ? const StoryPage() : hub == 1 ? const StoriesTab() : hub == 2 ? const CirclesPage() : const LettersPage()),
      ]);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const NileScene(),
      const MessagesTab(),
      _hub(),
      const PassportPage(),
    ];
    return Scaffold(
      backgroundColor: kBg,
      extendBody: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
      ),
      bottomNavigationBar: NiloNavBar(index: tab, onTab: (i) { setState(() => tab = i); if (i != 1) Health.refreshUnread(); }, onSend: _send),
    );
  }
}

class NileScene extends StatefulWidget {
  const NileScene({super.key});
  @override
  State<NileScene> createState() => _NileSceneState();
}

class _NileSceneState extends State<NileScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  int _real = 0, _people = 0;
  bool _checked = false;
  int _city = 0;
  int? _isDay;
  String _wx = '';
  static const _cities = [
    ['القاهرة', 'Cairo', '30.0444', '31.2357'],
    ['الجيزة', 'Giza', '29.9870', '31.2118'],
    ['الأقصر', 'Luxor', '25.6872', '32.6396'],
    ['أسوان', 'Aswan', '24.0889', '32.8998'],
    ['الإسكندرية', 'Alexandria', '31.2001', '29.9187'],
  ];
  static String _icon(int c, bool day) {
    if (c == 0) return day ? '☀️' : '🌙';
    if (c <= 2) return day ? '🌤️' : '☁️';
    if (c == 3 || c == 45 || c == 48) return '☁️';
    if (c >= 95) return '⛈️';
    if (c >= 51 && c <= 82) return '🌧️';
    return '🌡️';
  }
  /// Real weather from Open-Meteo (free, no key). Nothing is shown if it can't be fetched.
  Future<void> _weather() async {
    final c = _cities[_city];
    try {
      final r = await cachedGet('https://api.open-meteo.com/v1/forecast?latitude=${c[2]}&longitude=${c[3]}&current=temperature_2m,weather_code,is_day&timezone=Africa%2FCairo', 30, timeoutSec: 10);
      final cur = (jsonDecode(r.body) as Map)['current'] as Map;
      final day = (cur['is_day'] as num).toInt();
      final t = DateTime.now();
      final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      if (mounted) setState(() {
        _isDay = day;
        _wx = '${c[0]} • ${c[1]}  ${_icon((cur['weather_code'] as num).toInt(), day == 1)} ${(cur['temperature_2m'] as num).round()}°  $hm';
      });
    } catch (_) {
      if (mounted) setState(() => _wx = '');
    }
  }
  @override
  void initState() { super.initState(); _count(); _weather(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  /// Real number of papyri floating from other people (server count). Nothing is made up.
  Future<void> _count() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!((p.getBool('b_age') ?? false) && (p.getString('b_nick') ?? '').isNotEmpty)) { if (mounted) setState(() => _checked = true); return; }
      if (!await Sb.signIn()) return;
      final r = await Sb.rpc('floating_count');
      try { final s = await Sb.rpc('nilo_stats'); if (s is Map) _people = (s['people'] as num?)?.toInt() ?? 0; } catch (_) {}
      if (mounted) setState(() { _real = (r as num?)?.toInt() ?? 0; _checked = true; });
    } catch (_) {}
  }

  Future<void> _open(bool send) async {
    HapticFeedback.mediumImpact();
    final p = await SharedPreferences.getInstance();
    final joined = (p.getBool('b_age') ?? false) && (p.getString('b_nick') ?? '').isNotEmpty;
    if (!mounted) return;
    if (!joined) {
      Navigator.of(context).push(niloRoute(const BottlesPage()));
      return;
    }
    final lang = p.getString('b_lang') ?? 'en';
    final ok = await Sb.signIn();
    if (!mounted) return;
    if (!ok) { toast(context, 'No connection. Try again.'); return; }
    Navigator.of(context).push(niloRoute(send ? ThrowPage(lang: lang) : CatchPage(lang: lang)));
  }

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final night = _isDay == null ? (h >= 19 || h < 5) : _isDay == 0;
        final flagFor = Passport.country.isEmpty ? '🌍' : (kWorld.where((w) => w[0] == Passport.country).map((w) => w[3] as String).firstOrNull ?? '🌍');
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _ScenePainter(_c.value, night)))),
        ),
      ),
      // floating papyri with flag + country
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, hh = box.maxHeight;
        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final kids = <Widget>[];
            for (var i = 0; i < math.min(_real, 3); i++) {
              final ph = (_c.value + i / 3) % 1.0;
              final x = w * (0.08 + 0.55 * ((i * 0.37) % 1.0)) + math.sin((ph + i) * 2 * math.pi) * 10;
              final y = hh * (0.58 + 0.07 * i) + math.sin(ph * 2 * math.pi * 2) * 6;
              kids.add(Positioned(
                left: x, top: y,
                child: GestureDetector(
                  onTap: () => _open(false),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFFFF6DC), borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                      child: Text(L('بردية • Papyrus'), style: TextStyle(color: Color(0xFF3B2A12), fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    const SizedBox(height: 2),
                    Text(L('📜'), style: TextStyle(fontSize: 34)),
                  ]),
                ),
              ));
            }
            if (_checked && _real == 0) {
              kids.add(Positioned(
                left: 24, right: 24, top: hh * 0.62,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(14)),
                  child: Text(L('مفيش برديات لسه. كن أول واحد يبعت بردية!\nNo papyri yet. Be the first to send one.') + (_people >= 10 ? '\n$_people ${L('travelers joined')} • $_real ${L('papyri floating')}' : ''), textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
                ),
              ));
            }
            return Stack(children: kids);
          },
        );
      }),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Nilo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1, shadows: [Shadow(color: Colors.black38, blurRadius: 6)])),
                const SizedBox(width: 8),
                Text('نيلو', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kGreen)),
              ]))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(flagFor),
              _chip('📜 ${Passport.ink}/10'),
              GestureDetector(onTap: () => Navigator.of(context).push(niloRoute(const TodayPage())), child: _chip('🌍')),
              GestureDetector(onTap: () => Navigator.of(context).push(niloRoute(const ToolsPage())), child: _chip('🧰 ${L('Tools')}')),
              GestureDetector(onTap: () => Navigator.of(context).push(niloRoute(const GlobePage())), child: _chip('🌐 ${L('Globe')}')),
              GestureDetector(onTap: () => Navigator.of(context).push(niloRoute(const PlayHubPage())), child: _chip('🎲 ${L('Play')}')),
              if (_wx.isNotEmpty)
                GestureDetector(
                  onTap: () { setState(() => _city = (_city + 1) % _cities.length); _weather(); },
                  child: _chip(_wx),
                ),
            ]),
            const SizedBox(height: 8),
            const LandmarkStrip(),
          ]),
        ),
      ),
      Positioned(
        left: 0, right: 0, bottom: 26,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () => _open(false),
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.25), border: Border.all(color: Colors.white54)),
              alignment: Alignment.center,
              child: Text(L('🪶'), style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => _open(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFD9A441)]),
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [BoxShadow(color: Color(0xFF8A5A12), offset: Offset(0, 5)), BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 8))],
              ),
              child: Text(L('Send papyrus • ارسل بردية'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3B2A12))),
            ),
          ),
        ]),
      ),
      if (Passport.streak >= 2)
        Positioned(
          left: 0, right: 0, bottom: 96,
          child: IgnorePointer(child: Column(children: [
            Text('⛵' * math.min(Passport.streak, 10), style: const TextStyle(fontSize: 18)),
            Text('${L('Your fleet')}: ${Passport.streak} ${L('days')}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ])),
        ),
      Positioned(
        left: 0, right: 0, bottom: 4,
        child: Text(_real > 0 ? 'Tap a papyrus to catch it' : '', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white70)),
      ),
    ]);
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white30)),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
      );
}

class _ScenePainter extends CustomPainter {
  final double t;
  final bool night;
  _ScenePainter(this.t, this.night);
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final horizon = h * 0.40;
    final sky = night
        ? const [Color(0xFF050E1A), Color(0xFF12294A), Color(0xFF2B3F66)]
        : const [Color(0xFF3F4E86), Color(0xFFE08A5B), Color(0xFFFFD58A)];
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon + 2), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky).createShader(Rect.fromLTWH(0, 0, w, horizon)));
    if (night) {
      for (var i = 0; i < 22; i++) {
        final tw = 0.4 + 0.6 * ((math.sin(t * 4 * math.pi + i) + 1) / 2);
        canvas.drawCircle(Offset((i * 37 % 100) / 100 * w, (i * 61 % 100) / 100 * horizon), 0.8 + (i % 3) * 0.4, Paint()..color = Colors.white.withOpacity(0.55 * tw));
      }
      canvas.drawCircle(Offset(w * 0.86, h * 0.31), 22, Paint()..color = const Color(0xFFF3E9C6));
    } else {
      final sc = Offset(w * 0.68, horizon - 20);
      canvas.drawCircle(sc, 80, Paint()..color = const Color(0x33FFE9A8));
      canvas.drawCircle(sc, 50, Paint()..color = const Color(0x55FFE9A8));
      canvas.drawCircle(sc, 32, Paint()..color = const Color(0xFFFFF1C4));
    }
    // far dunes and pyramids
    final dune = Path()..moveTo(0, horizon)..quadraticBezierTo(w * 0.25, horizon - 26, w * 0.5, horizon - 8)..quadraticBezierTo(w * 0.8, horizon - 30, w, horizon - 6)..lineTo(w, horizon + 2)..lineTo(0, horizon + 2)..close();
    canvas.drawPath(dune, Paint()..color = night ? const Color(0xFF0E1B30) : const Color(0xFFB86F4A));
    final pyr = Paint()..color = night ? const Color(0xFF0A1424) : const Color(0xFF8E5238);
    for (final p in [[0.16, 54.0, 44.0], [0.28, 36.0, 30.0], [0.09, 26.0, 22.0]]) {
      final cx = w * p[0], bw = p[1], bh = p[2];
      canvas.drawPath(Path()..moveTo(cx - bw, horizon - 4)..lineTo(cx, horizon - 4 - bh)..lineTo(cx + bw, horizon - 4)..close(), pyr);
    }
    // palms on far bank
    for (final px in [0.55, 0.62, 0.9]) {
      final x = w * px;
      canvas.drawRect(Rect.fromLTWH(x - 1.5, horizon - 26, 3, 24), pyr);
      for (var a = -2; a <= 2; a++) {
        canvas.drawPath(Path()..moveTo(x, horizon - 26)..quadraticBezierTo(x + a * 12, horizon - 40 + a.abs() * 4, x + a * 18, horizon - 22 + a.abs() * 3), Paint()..color = pyr.color..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
    }
    // water
    final wr = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(wr, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: night ? const [Color(0xFF1B3358), Color(0xFF0A1B30)] : const [Color(0xFFF2B36A), Color(0xFF3F8FA8), Color(0xFF1B5A7A)]).createShader(wr));
    // sun glitter
    if (!night) {
      for (var i = 0; i < 14; i++) {
        final y = horizon + 8 + i * 9.0;
        final ww = 60 - i * 2.5 + math.sin(t * 2 * math.pi + i) * 8;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.68 + math.sin(t * 2 * math.pi * 2 + i) * 6, y), width: ww.abs(), height: 2.6), const Radius.circular(2)), Paint()..color = const Color(0xFFFFF1C4).withOpacity(0.55 - i * 0.03));
      }
    }
    // waves
    final wp = Paint()..color = Colors.white.withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 1.6;
    for (var r = 0; r < 7; r++) {
      final y = horizon + 40 + r * ((h - horizon) / 8);
      final p = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += 12) { p.lineTo(x, y + math.sin((x / 40) + t * 2 * math.pi * (1 + r % 2) + r) * 3); }
      canvas.drawPath(p, wp);
    }
    // felucca with avatar
    final bob = math.sin(t * 2 * math.pi * 2) * 4;
    final cx = w * 0.5, cy = h * 0.47 + bob;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.sin(t * 2 * math.pi * 2 + 1) * 0.03);
    // reflection
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 40), width: 190, height: 14), Paint()..color = Colors.black.withOpacity(0.18));
    // hull
    final hull = Path()..moveTo(-96, 6)..quadraticBezierTo(-70, 40, 0, 40)..quadraticBezierTo(70, 40, 100, -6)..quadraticBezierTo(60, 8, 0, 8)..quadraticBezierTo(-50, 8, -96, 6)..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFF6B3E1E));
    canvas.drawPath(Path()..moveTo(-96, 6)..quadraticBezierTo(-50, 8, 0, 8)..quadraticBezierTo(60, 8, 100, -6), Paint()..color = const Color(0xFFD9A441)..style = PaintingStyle.stroke..strokeWidth = 3);
    // mast and sail
    canvas.drawRect(const Rect.fromLTWH(-3, -150, 5, 158), Paint()..color = const Color(0xFF4A2A12));
    final sail = Path()..moveTo(2, -148)..quadraticBezierTo(70 + math.sin(t * 2 * math.pi * 2) * 6, -80, 92, -4)..lineTo(2, -4)..close();
    canvas.drawPath(sail, Paint()..shader = const LinearGradient(colors: [Color(0xFFFFF2D0), Color(0xFFE9C987)]).createShader(const Rect.fromLTWH(0, -150, 100, 150)));
    canvas.drawPath(Path()..moveTo(-3, -150)..lineTo(-70, -10)..lineTo(-3, -10)..close(), Paint()..color = const Color(0xFFFFE9B0).withOpacity(0.9));
    // avatar
    final skin = Paint()..color = const Color(0xFFC98E62);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-48, -34, 22, 34), const Radius.circular(8)), Paint()..color = const Color(0xFF1F3A5C));
    canvas.drawCircle(const Offset(-37, -44), 11, skin);
    canvas.drawArc(const Rect.fromLTWH(-49, -57, 24, 20), math.pi, math.pi, true, Paint()..color = const Color(0xFFD9A441));
    canvas.drawCircle(const Offset(-40, -43), 1.4, Paint()..color = Colors.black87);
    canvas.drawCircle(const Offset(-34, -43), 1.4, Paint()..color = Colors.black87);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) => o.t != t;
}

/// Messages tab: real inbox when joined, otherwise the join gate.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});
  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  Widget? page;
  @override
  void initState() { super.initState(); _go(); }
  Future<void> _go() async {
    final p = await SharedPreferences.getInstance();
    final joined = (p.getBool('b_age') ?? false) && (p.getString('b_nick') ?? '').isNotEmpty;
    Widget w = const BottlesPage();
    if (joined) {
      final ok = await Sb.signIn().timeout(const Duration(seconds: 12), onTimeout: () => false);
      if (ok) { w = InboxPage(lang: p.getString('b_lang') ?? 'en'); }
      else {
        w = Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('No connection. Try again.'), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () { setState(() => page = null); _go(); }, child: Text(L('Retry'))),
        ]))));
      }
    }
    if (mounted) setState(() => page = w);
  }
  @override
  Widget build(BuildContext context) => page ?? const Scaffold(body: Center(child: CircularProgressIndicator()));
}
