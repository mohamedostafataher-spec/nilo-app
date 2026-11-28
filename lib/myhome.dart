import 'quests.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport, kWorld;
import 'vr.dart' show VrPage;

/// My Home: your own house and garden, drawn on the phone. Look depends on your home country.
/// Slots hold items you unlock with Reeds. Your focus palms and stamps show up here too.
/// Everything is local. No other person can see it (visiting between friends comes later).
class _Look {
  final Color wall, roof, trim;
  final String style; // flat, gable, pagoda, dome
  const _Look(this.wall, this.roof, this.trim, this.style);
}

const _looks = <String, _Look>{
  'EG': _Look(Color(0xFFD9B77A), Color(0xFFB98A4B), Color(0xFF5E3B1B), 'flat'),
  'JP': _Look(Color(0xFFF1E6D0), Color(0xFF3B3B4A), Color(0xFF8A2B2B), 'pagoda'),
  'CN': _Look(Color(0xFFE7C9A0), Color(0xFFB3202A), Color(0xFFD9A441), 'pagoda'),
  'KR': _Look(Color(0xFFEFE3CF), Color(0xFF444B55), Color(0xFF7A4A2B), 'pagoda'),
  'FR': _Look(Color(0xFFE9E1D3), Color(0xFF4A5666), Color(0xFF6B7A8F), 'gable'),
  'GB': _Look(Color(0xFFB5543A), Color(0xFF3B3F46), Color(0xFFEDE6D8), 'gable'),
  'CA': _Look(Color(0xFFC8B79A), Color(0xFF8A2B2B), Color(0xFFEDE6D8), 'gable'),
  'US': _Look(Color(0xFFE8E2D6), Color(0xFF5A6B7A), Color(0xFFB3202A), 'gable'),
  'DE': _Look(Color(0xFFEEE4CF), Color(0xFF9A4A2B), Color(0xFF5E4630), 'gable'),
  'IT': _Look(Color(0xFFEBC48A), Color(0xFFC1623A), Color(0xFF7A5A3A), 'gable'),
  'ES': _Look(Color(0xFFF3EBDD), Color(0xFFC1623A), Color(0xFF2F5E8A), 'gable'),
  'TR': _Look(Color(0xFFEDE3D0), Color(0xFF2F7A8A), Color(0xFFD9A441), 'dome'),
  'SA': _Look(Color(0xFFDDBE8A), Color(0xFFC9A66B), Color(0xFF5E3B1B), 'dome'),
  'IN': _Look(Color(0xFFF0C8A0), Color(0xFFD9A441), Color(0xFFB3202A), 'dome'),
  'MX': _Look(Color(0xFFE88A5C), Color(0xFFB5543A), Color(0xFF2F8A7A), 'flat'),
  'BR': _Look(Color(0xFFF2D06B), Color(0xFF2F8A5A), Color(0xFF2F5E8A), 'gable'),
};
const _fallback = _Look(Color(0xFFE2D2B0), Color(0xFF8A6A4A), Color(0xFF4A3A2A), 'gable');

/// slot id, label, options (emoji, price in Reeds; 0 = free)
const _slots = <String, List<Object>>{
  'left': ['Garden', ['🌴:0', '🌳:10', '🌸:15', '🌵:15', '🎄:20']],
  'right': ['Corner', ['🪑:10', '🛶:25', '⛲:40', '🐈:30', '🐕:30']],
  'sky': ['Sky', ['🏳️:0', '🪁:15', '🎈:15', '🦅:25', '🛸:40']],
  'door': ['Door', ['🪔:10', '🕯️:10', '🔔:15', '🏮:20']],
  'window': ['Window', ['🪴:10', '📚:15', '🎨:20', '🔭:30']],
};

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, String> placed = {};
  int trees = 0, stamps = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try { placed = Map<String, String>.from(jsonDecode(p.getString('home_slots') ?? '{}')); } catch (_) {}
    trees = p.getInt('focus_trees') ?? 0;
    stamps = (p.getStringList('globe_stamps') ?? <String>[]).length;
    if (mounted) setState(() {});
  }

  String _flag() {
    for (final w in kWorld) { if (w[0] == Passport.country) return w[3] as String; }
    return '🏳️';
  }

  String _show(String slot) {
    final e = placed[slot];
    if (e == null) return '';
    return e == '🏳️' ? _flag() : e;
  }

  Future<void> _pick(String slot) async {
    final info = _slots[slot]!;
    final opts = (info[1] as List).cast<String>();
    final choice = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${L(info[0] as String)}  •  ${Passport.reeds} 🌿', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final o in opts)
          Builder(builder: (_) {
            final e = o.split(':')[0], price = int.parse(o.split(':')[1]);
            final own = price == 0 || Passport.owned.contains('home_$e');
            return ActionChip(
              label: Text(own ? (e == '🏳️' ? _flag() : e) : '${e == '🏳️' ? _flag() : e} $price🌿', style: const TextStyle(fontSize: 20)),
              onPressed: () => Navigator.pop(context, o),
            );
          }),
        ActionChip(label: const Icon(Icons.clear, size: 18), onPressed: () => Navigator.pop(context, 'none')),
      ]),
    ]))));
    if (choice == null) return;
    final p = await SharedPreferences.getInstance();
    if (choice == 'none') { placed.remove(slot); } else {
      final e = choice.split(':')[0], price = int.parse(choice.split(':')[1]);
      if (price > 0 && !Passport.owned.contains('home_$e')) {
        if (!Passport.spendReeds(price)) { if (mounted) toast(context, 'Not enough Reeds yet. Daily question, weekly challenge and focus palms give Reeds.'); return; }
        Passport.own('home_$e');
      }
      placed[slot] = e;
    }
    await p.setString('home_slots', jsonEncode(placed));
    if (mounted) setState(() {});
  }

  Widget _slot(String slot, double left, double top, double size) => Positioned(
        left: left, top: top,
        child: GestureDetector(
          onTap: () => _pick(slot),
          child: Container(
            width: size + 10, height: size + 10, alignment: Alignment.center,
            decoration: _show(slot).isEmpty ? BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(10)) : null,
            child: Text(_show(slot).isEmpty ? '+' : _show(slot), style: TextStyle(fontSize: size, color: Colors.white54)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final look = _looks[Passport.country.toUpperCase()] ?? _fallback;
    final hour = DateTime.now().hour;
    final night = hour < 6 || hour >= 19;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('My Home • بيتي')), backgroundColor: kBg, automaticallyImplyLeading: false, actions: [
        Center(child: Padding(padding: const EdgeInsets.only(right: 14), child: Text('${Passport.reeds} 🌿', style: const TextStyle(fontWeight: FontWeight.w800)))),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 360,
            child: LayoutBuilder(builder: (_, box) {
              final w = box.maxWidth;
              return Stack(children: [
                Positioned.fill(child: _Scene(look: look, night: night, trees: trees)),
                _slot('sky', w * 0.70, 12, 34),
                _slot('left', w * 0.03, 215, 42),
                _slot('right', w * 0.80, 250, 38),
                _slot('door', w * 0.46, 214, 26),
                _slot('window', w * 0.29, 166, 26),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kGreen, foregroundColor: kBg, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VrPage(scene: 'myroom', title: L('My room • أوضتي')))),
          icon: const Icon(Icons.meeting_room),
          label: Text(L('Walk inside your room • ادخل أوضتك'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        const QuestsCard(),
        const SizedBox(height: 12),
        Text(L('Tap a + to place something. Items cost Reeds. Your look follows your home country.\nدوس على + لتحط حاجة. الحاجات بالقرشة (Reeds). شكل البيت حسب بلدك.'), style: const TextStyle(color: Colors.white60, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          _stat('🌴', '$trees', L('Focus palms')),
          _stat('🛂', '$stamps', L('Stamps')),
          _stat(_flag(), Passport.country.isEmpty ? '—' : Passport.country.toUpperCase(), L('Home country')),
        ]),
        const SizedBox(height: 10),
        Text(L('Coming later: invite a mutual friend to visit. Only friends, you choose who enters, and you can close the door.'), style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }

  Widget _stat(String e, String v, String l) => Expanded(child: Card(color: Colors.white10, child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
        Text(e, style: const TextStyle(fontSize: 24)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.white54), textAlign: TextAlign.center),
      ]))));
}

class _Scene extends StatefulWidget {
  final _Look look;
  final bool night;
  final int trees;
  const _Scene({required this.look, required this.night, required this.trees});
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  @override
  void dispose() { ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _HomePainter(widget.look, widget.night, widget.trees, ac));
}

Color _sh(Color c, double f) => Color.fromARGB(255, (c.red * f).round().clamp(0, 255), (c.green * f).round().clamp(0, 255), (c.blue * f).round().clamp(0, 255));

class _HomePainter extends CustomPainter {
  final _Look look;
  final bool night;
  final int trees;
  final Animation<double> anim;
  _HomePainter(this.look, this.night, this.trees, this.anim) : super(repaint: anim);

  static final _ol = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..color = const Color(0x66000000)..strokeJoin = StrokeJoin.round;

  void _cloud(Canvas c, double x, double y, double k) {
    final p = Paint()..color = night ? const Color(0x55CFD8F5) : const Color(0xF2FFFFFF);
    c.drawCircle(Offset(x, y), 14 * k, p);
    c.drawCircle(Offset(x + 16 * k, y - 8 * k), 18 * k, p);
    c.drawCircle(Offset(x + 34 * k, y), 15 * k, p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 10 * k, y, 58 * k, 14 * k), Radius.circular(8 * k)), p);
  }

  void _bush(Canvas c, double x, double y, double r, Color base) {
    c.drawCircle(Offset(x, y), r, Paint()..color = _sh(base, 0.8));
    c.drawCircle(Offset(x - r * 0.7, y + r * 0.2), r * 0.75, Paint()..color = _sh(base, 0.9));
    c.drawCircle(Offset(x + r * 0.7, y + r * 0.2), r * 0.75, Paint()..color = base);
    c.drawCircle(Offset(x - r * 0.2, y - r * 0.3), r * 0.35, Paint()..color = _sh(base, 1.2));
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, t = anim.value * 60.0; // seconds
    final gy = h * 0.70; // ground line at the house
    // sky
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: night ? const [Color(0xFF080E2A), Color(0xFF26356A), Color(0xFF6A6AA0)] : const [Color(0xFF2F8FE0), Color(0xFF86CBF4), Color(0xFFFFF0C8)], stops: const [0, 0.55, 1]).createShader(Rect.fromLTWH(0, 0, w, gy)));
    if (night) {
      final r = math.Random(7);
      for (var i = 0; i < 40; i++) {
        final tw = 0.5 + 0.5 * math.sin(t * 2 + i);
        c.drawCircle(Offset(r.nextDouble() * w, r.nextDouble() * h * 0.45), 0.8 + tw * 1.2, Paint()..color = Colors.white.withOpacity(0.4 + 0.6 * tw));
      }
      c.drawCircle(Offset(w * 0.15, 48), 34, Paint()..color = const Color(0x22F3EBC8));
      c.drawCircle(Offset(w * 0.15, 48), 18, Paint()..color = const Color(0xFFF6F0D0));
      c.drawCircle(Offset(w * 0.15 + 6, 44), 16, Paint()..color = const Color(0xFF26356A)..blendMode = BlendMode.srcATop);
    } else {
      final sc = Offset(w * 0.17, 52);
      c.drawCircle(sc, 70, Paint()..shader = RadialGradient(colors: const [Color(0x99FFF3A0), Color(0x00FFF3A0)]).createShader(Rect.fromCircle(center: sc, radius: 70)));
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6 + t * 0.05;
        c.drawLine(sc + Offset(math.cos(a) * 26, math.sin(a) * 26), sc + Offset(math.cos(a) * 38, math.sin(a) * 38), Paint()..color = const Color(0xAAFFE27A)..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
      c.drawCircle(sc, 22, Paint()..color = const Color(0xFFFFD84D));
      c.drawCircle(sc + const Offset(-6, -6), 8, Paint()..color = const Color(0x66FFFFFF));
    }
    // clouds drift
    _cloud(c, ((t * 6) % (w + 120)) - 80, 70, 1.0);
    _cloud(c, ((t * 3.5 + w * 0.6) % (w + 120)) - 80, 118, 0.7);
    _cloud(c, ((t * 4.5 + w * 0.3) % (w + 120)) - 80, 40, 0.55);
    // far backdrop: pyramids for Egypt, mountains elsewhere
    final far = night ? const Color(0xFF3A4478) : const Color(0xFF8FB4D8);
    if (Passport.country.toUpperCase() == 'EG') {
      final sand = night ? const Color(0xFF6B6270) : const Color(0xFFE8C57A);
      for (final pr in [[0.62, 0.30, 70.0], [0.80, 0.20, 52.0], [0.92, 0.12, 36.0]]) {
        final cx = w * pr[0], ph = pr[2];
        c.drawPath(Path()..moveTo(cx - ph * 1.1, gy - 18)..lineTo(cx, gy - 18 - ph)..lineTo(cx + ph * 1.1, gy - 18)..close(), Paint()..color = sand);
        c.drawPath(Path()..moveTo(cx, gy - 18 - ph)..lineTo(cx + ph * 1.1, gy - 18)..lineTo(cx + ph * 0.3, gy - 18)..close(), Paint()..color = _sh(sand, 0.82));
      }
    } else {
      c.drawPath(Path()..moveTo(0, gy - 14)..lineTo(w * 0.15, gy - 80)..lineTo(w * 0.3, gy - 30)..lineTo(w * 0.5, gy - 100)..lineTo(w * 0.7, gy - 36)..lineTo(w * 0.85, gy - 76)..lineTo(w, gy - 24)..lineTo(w, gy)..lineTo(0, gy)..close(), Paint()..color = far);
      c.drawPath(Path()..moveTo(w * 0.5, gy - 100)..lineTo(w * 0.44, gy - 78)..lineTo(w * 0.5, gy - 84)..lineTo(w * 0.55, gy - 76)..close(), Paint()..color = Colors.white.withOpacity(night ? 0.4 : 0.9));
    }
    // hills
    final g1 = night ? const Color(0xFF2B4A38) : const Color(0xFF7CC464), g2 = night ? const Color(0xFF244030) : const Color(0xFF5FAF4C);
    c.drawPath(Path()..moveTo(0, gy - 6)..quadraticBezierTo(w * 0.25, gy - 46, w * 0.55, gy - 12)..quadraticBezierTo(w * 0.8, gy - 34, w, gy - 8)..lineTo(w, h)..lineTo(0, h)..close(), Paint()..color = g1);
    c.drawRect(Rect.fromLTWH(0, gy - 4, w, h - gy + 4), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [g2, _sh(g2, 0.7)]).createShader(Rect.fromLTWH(0, gy, w, h - gy)));
    // path from door to the bottom
    final path = Path()..moveTo(w * 0.43, gy)..quadraticBezierTo(w * 0.36, h * 0.82, w * 0.30, h)..lineTo(w * 0.62, h)..quadraticBezierTo(w * 0.52, h * 0.82, w * 0.51, gy)..close();
    c.drawPath(path, Paint()..color = night ? const Color(0xFF6A5E4A) : const Color(0xFFE9D3A2));
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x33000000));
    // house
    final hx = w * 0.28, hw = w * 0.38, hy = h * 0.40, hh = gy - hy, sd = w * 0.09;
    c.drawOval(Rect.fromLTWH(hx - 12, gy - 8, hw + sd + 30, 22), Paint()..color = const Color(0x44000000));
    // side wall (darker) and front wall
    final sidePath = Path()..moveTo(hx + hw, hy)..lineTo(hx + hw + sd, hy + 10)..lineTo(hx + hw + sd, gy - 8)..lineTo(hx + hw, gy)..close();
    c.drawPath(sidePath, Paint()..color = _sh(look.wall, 0.72));
    c.drawPath(sidePath, _ol);
    final front = Rect.fromLTWH(hx, hy, hw, hh);
    c.drawRect(front, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_sh(look.wall, 1.1), look.wall, _sh(look.wall, 0.9)]).createShader(front));
    c.drawRect(front, _ol);
    // brick-like lines
    final ln = Paint()..color = const Color(0x14000000)..strokeWidth = 1;
    for (var y = hy + 14; y < gy; y += 14) { c.drawLine(Offset(hx, y), Offset(hx + hw, y), ln); }
    // roof
    final rc = look.roof, rd = _sh(look.roof, 0.78), rl = _sh(look.roof, 1.18);
    switch (look.style) {
      case 'flat':
        c.drawRect(Rect.fromLTWH(hx - 8, hy - 14, hw + sd + 16, 18), Paint()..color = rc);
        c.drawRect(Rect.fromLTWH(hx - 8, hy - 14, hw + sd + 16, 18), _ol);
        c.drawRect(Rect.fromLTWH(hx - 8, hy - 14, hw + sd + 16, 5), Paint()..color = rl);
        c.drawRect(Rect.fromLTWH(hx + hw * 0.12, hy - 34, hw * 0.28, 20), Paint()..color = look.wall);
        c.drawRect(Rect.fromLTWH(hx + hw * 0.12, hy - 34, hw * 0.28, 20), _ol);
        break;
      case 'pagoda':
        for (final tier in [[0.0, 1.0], [-30.0, 0.62]]) {
          final dy = tier[0], k = tier[1];
          final l = hx - 26 * k + (1 - k) * hw * 0.5, r = hx + hw + sd + 26 * k - (1 - k) * hw * 0.5, ty = hy + 8 + dy;
          final top = Path()..moveTo(l, ty)..quadraticBezierTo((l + r) / 2, ty - 62 * k, r, ty)..quadraticBezierTo((l + r) / 2, ty - 12, l, ty)..close();
          c.drawPath(top, Paint()..color = rc);
          c.drawPath(top, _ol);
          c.drawPath(Path()..moveTo((l + r) / 2, ty - 46 * k)..quadraticBezierTo((l + r) / 2 + (r - l) * 0.25, ty - 28 * k, r, ty)..quadraticBezierTo((l + r) / 2, ty - 12, (l + r) / 2, ty - 12)..close(), Paint()..color = rd);
        }
        break;
      case 'dome':
        final dr = Rect.fromLTWH(hx + 6, hy - hw * 0.46, hw - 12, hw * 0.92);
        c.drawArc(dr, math.pi, math.pi, true, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.6), colors: [rl, rc, rd]).createShader(dr));
        c.drawArc(dr, math.pi, math.pi, true, _ol);
        c.drawRect(Rect.fromLTWH(hx - 6, hy - 8, hw + sd + 12, 14), Paint()..color = rd);
        c.drawLine(Offset(hx + hw / 2, hy - hw * 0.46), Offset(hx + hw / 2, hy - hw * 0.46 - 16), Paint()..color = look.trim..strokeWidth = 3);
        c.drawCircle(Offset(hx + hw / 2, hy - hw * 0.46 - 18), 4, Paint()..color = const Color(0xFFFFD84D));
        break;
      default:
        final ap = Offset(hx + hw / 2 + sd * 0.5, hy - 58);
        final lp = Path()..moveTo(hx - 14, hy + 4)..lineTo(ap.dx, ap.dy)..lineTo(ap.dx, hy + 12)..close();
        final rp = Path()..moveTo(ap.dx, ap.dy)..lineTo(hx + hw + sd + 14, hy + 14)..lineTo(ap.dx, hy + 12)..close();
        c.drawPath(lp, Paint()..color = rl);
        c.drawPath(rp, Paint()..color = rd);
        c.drawPath(lp, _ol);
        c.drawPath(rp, _ol);
        // chimney + smoke
        final chx = hx + hw * 0.12;
        c.drawRect(Rect.fromLTWH(chx, hy - 44, 16, 30), Paint()..color = _sh(look.wall, 0.8));
        c.drawRect(Rect.fromLTWH(chx, hy - 44, 16, 30), _ol);
        for (var i = 0; i < 4; i++) {
          final ph = ((t * 0.5 + i * 0.25) % 1.0);
          c.drawCircle(Offset(chx + 8 + math.sin(ph * 6 + i) * 6 + ph * 14, hy - 48 - ph * 50), 5 + ph * 8, Paint()..color = Colors.white.withOpacity((1 - ph) * 0.6));
        }
    }
    // door with arch
    final dx = hx + hw / 2 - 18, dh = 56.0;
    final doorP = Path()..moveTo(dx, gy)..lineTo(dx, gy - dh + 18)..arcToPoint(Offset(dx + 36, gy - dh + 18), radius: const Radius.circular(18))..lineTo(dx + 36, gy)..close();
    c.drawPath(doorP, Paint()..color = look.trim);
    c.drawPath(doorP, _ol);
    c.drawCircle(Offset(dx + 28, gy - 26), 3, Paint()..color = const Color(0xFFFFD84D));
    c.drawRect(Rect.fromLTWH(dx - 8, gy - 3, 52, 5), Paint()..color = _sh(look.wall, 0.7));
    // window with glow, frame cross and flower box
    final wr = Rect.fromLTWH(hx + 14, hy + 24, 40, 38);
    c.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(5)), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: night ? const [Color(0xFFFFE27A), Color(0xFFFFB84D)] : const [Color(0xFFCDEBFB), Color(0xFF7FC3EA)]).createShader(wr));
    c.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(5)), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = look.trim);
    c.drawLine(Offset(wr.center.dx, wr.top), Offset(wr.center.dx, wr.bottom), Paint()..color = look.trim..strokeWidth = 2);
    c.drawLine(Offset(wr.left, wr.center.dy), Offset(wr.right, wr.center.dy), Paint()..color = look.trim..strokeWidth = 2);
    c.drawRect(Rect.fromLTWH(wr.left - 3, wr.bottom + 1, wr.width + 6, 8), Paint()..color = _sh(look.trim, 0.9));
    for (var i = 0; i < 4; i++) { c.drawCircle(Offset(wr.left + 5 + i * 10, wr.bottom - 1), 4, Paint()..color = [Colors.pinkAccent, Colors.amber, Colors.redAccent, Colors.white][i]); }
    // little side window on the side wall
    c.drawRect(Rect.fromLTWH(hx + hw + sd * 0.3, hy + 34, sd * 0.4, 24), Paint()..color = night ? const Color(0xFFFFD27A) : const Color(0xFF7FC3EA));
    // fence
    final fc = night ? const Color(0xFF9A8F78) : const Color(0xFFF4EBD5);
    for (var i = 0; i < 6; i++) {
      final fx = hx - 90 + i * 15.0;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(fx, gy - 4, 9, 26), const Radius.circular(3)), Paint()..color = fc);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(fx, gy - 4, 9, 26), const Radius.circular(3)), _ol);
    }
    c.drawRect(Rect.fromLTWH(hx - 92, gy + 4, 88, 4), Paint()..color = fc);
    // bushes and flowers
    final bc = night ? const Color(0xFF2F6A45) : const Color(0xFF3FA05A);
    _bush(c, hx - 6, gy + 4, 14, bc);
    _bush(c, hx + hw + sd + 6, gy + 2, 16, bc);
    final fr = math.Random(3);
    for (var i = 0; i < 16; i++) {
      final fx = fr.nextDouble() * w, fy = gy + 12 + fr.nextDouble() * (h - gy - 24);
      if (fx > w * 0.30 && fx < w * 0.62 && fy > gy) continue;
      final sw = math.sin(t * 2 + i) * 1.5;
      c.drawLine(Offset(fx, fy), Offset(fx + sw, fy - 8), Paint()..color = const Color(0xFF2F7A3A)..strokeWidth = 1.6);
      c.drawCircle(Offset(fx + sw, fy - 9), 3.2, Paint()..color = [Colors.pinkAccent, Colors.amber, Colors.white, Colors.deepOrangeAccent][i % 4]);
    }
    // birds (day) / fireflies (night)
    if (!night) {
      for (var i = 0; i < 3; i++) {
        final bx = ((t * 18 + i * 90) % (w + 80)) - 40, by = 60 + i * 22 + math.sin(t * 2 + i) * 6, f = math.sin(t * 9 + i) * 4;
        final bp = Path()..moveTo(bx - 8, by - f)..quadraticBezierTo(bx - 3, by - 4, bx, by)..quadraticBezierTo(bx + 3, by - 4, bx + 8, by - f);
        c.drawPath(bp, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..color = const Color(0xFF2A3A4A));
      }
    } else {
      final r = math.Random(11);
      for (var i = 0; i < 14; i++) {
        final bx = r.nextDouble() * w + math.sin(t + i) * 10, by = gy - 20 + r.nextDouble() * (h - gy) * 0.8 + math.cos(t * 1.3 + i) * 8;
        final a = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 3 + i * 2));
        c.drawCircle(Offset(bx, by), 5, Paint()..color = const Color(0xFFFFF29A).withOpacity(a * 0.3));
        c.drawCircle(Offset(bx, by), 1.8, Paint()..color = const Color(0xFFFFF29A).withOpacity(a));
      }
    }
    // focus palms
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < math.min(trees, 12); i++) {
      tp.text = const TextSpan(text: '🌴', style: TextStyle(fontSize: 24));
      tp.layout();
      tp.paint(c, Offset(6 + i * (w - 40) / 12, h * 0.90));
    }
    // soft vignette
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = RadialGradient(radius: 1.0, colors: const [Color(0x00000000), Color(0x33000000)], stops: const [0.7, 1.0]).createShader(Rect.fromLTWH(0, 0, w, h)));
  }

  @override
  bool shouldRepaint(covariant _HomePainter o) => o.look != look || o.night != night || o.trees != trees;
}
