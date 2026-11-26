import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

/// The send sequence (about 4 seconds, tap to skip): the page settles, rolls up, a wax seal drops,
/// a cord ties it, it lands on a felucca and sails off. Pure drawing, no assets.
class SendSequence extends StatefulWidget {
  final VoidCallback onDone;
  const SendSequence({super.key, required this.onDone});
  @override
  State<SendSequence> createState() => _SendSequenceState();
}

class _SendSequenceState extends State<SendSequence> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
  bool _done = false, _sealTick = false;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      if (p.getBool('reduce_motion') ?? false) { _finish(); return; }
      _c.addListener(() {
        if (!_sealTick && _c.value > 0.37) { _sealTick = true; HapticFeedback.heavyImpact(); }
      });
      _c.forward().whenComplete(_finish);
    });
  }
  void _finish() { if (_done) return; _done = true; widget.onDone(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Container(
          color: kBg,
          child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _SendPainter(_c.value), size: Size.infinite)),
        ),
      );
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _ease(double x) => x * x * (3 - 2 * x);

class _SendPainter extends CustomPainter {
  final double t;
  _SendPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // sky + water
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF07131F), Color(0xFF0B1F33), Color(0xFF12304D)]).createShader(Offset.zero & s));
    final waterY = h * 0.66;
    c.drawRect(Rect.fromLTWH(0, waterY, w, h - waterY), Paint()..color = const Color(0xFF0E2A44));
    final wl = Paint()..color = const Color(0x33FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (var i = 0; i < 5; i++) {
      final y = waterY + 14 + i * 22.0;
      final p = Path()..moveTo(0, y);
      for (double x = 0; x <= w; x += 8) { p.lineTo(x, y + math.sin(x / 26 + t * 14 + i) * 3); }
      c.drawPath(p, wl);
    }
    // stage values
    final settle = _seg(t, 0.0, 0.15), roll = _ease(_seg(t, 0.15, 0.35)), seal = _seg(t, 0.35, 0.47), cord = _seg(t, 0.47, 0.60);
    final land = _ease(_seg(t, 0.60, 0.80)), sail = _ease(_seg(t, 0.80, 1.0));
    final boatIn = _seg(t, 0.45, 0.62);
    // boat
    final boatX = w * 0.5 + sail * w * 0.75;
    final bob = math.sin(t * 20) * 3;
    final by = waterY + 6 + bob;
    c.save();
    c.translate(boatX, by);
    c.rotate(math.sin(t * 20 + 1) * 0.04);
    final op = boatIn;
    final hull = Path()..moveTo(-70, -6)..quadraticBezierTo(0, 34, 70, -6)..close();
    c.drawPath(hull, Paint()..color = const Color(0xFF8B5A2B).withOpacity(op));
    c.drawPath(hull, Paint()..color = kGreen.withOpacity(op)..style = PaintingStyle.stroke..strokeWidth = 2);
    c.drawLine(const Offset(-6, -6), const Offset(-6, -92), Paint()..color = const Color(0xFFD9C8A0).withOpacity(op)..strokeWidth = 3);
    final sailP = Path()..moveTo(-2, -90)..quadraticBezierTo(48 + sail * 8, -52, 52, -10)..lineTo(-2, -10)..close();
    c.drawPath(sailP, Paint()..color = const Color(0xFFF2E8D0).withOpacity(op));
    c.restore();
    // wake
    if (sail > 0) {
      final wp = Paint()..color = Colors.white.withOpacity(0.35 * (1 - sail))..style = PaintingStyle.stroke..strokeWidth = 2;
      c.drawLine(Offset(boatX - 90, by + 16), Offset(boatX - 90 - 90 * sail, by + 20), wp);
      c.drawLine(Offset(boatX - 80, by + 24), Offset(boatX - 80 - 70 * sail, by + 28), wp);
    }
    // scroll
    final cx0 = w * 0.5, cy0 = h * 0.34;
    final cx = _lerp(cx0, boatX + 4, land), cy = _lerp(cy0, by - 24, land) + (land > 0 && sail == 0 ? 0 : 0);
    final sc = _lerp(1.0, 0.45, land);
    c.save();
    c.translate(cx, cy);
    c.scale(sc);
    final pageW = w * 0.62;
    final pageH = _lerp(h * 0.34, 34, roll);
    final paper = Paint()..color = const Color(0xFFE9D8A6);
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: pageW, height: pageH), Radius.circular(roll > 0.9 ? 17 : 6));
    if (settle > 0 && roll < 1) {
      c.drawRRect(rect.inflate(2), Paint()..color = kGreen.withOpacity(0.25 * (1 - roll))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    c.drawRRect(rect, paper);
    c.drawRRect(rect, Paint()..color = const Color(0xFF9C7A3C)..style = PaintingStyle.stroke..strokeWidth = 2);
    if (roll < 0.7) {
      final ink = Paint()..color = const Color(0xFF5A4320).withOpacity(1 - roll / 0.7)..strokeWidth = 2.2..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final y = -pageH / 2 + 28 + i * 30.0;
        if (y > pageH / 2 - 14) break;
        final len = pageW * (0.82 - (i % 3) * 0.12) * (0.5 + 0.5 * settle);
        c.drawLine(Offset(-pageW / 2 + 18, y), Offset(-pageW / 2 + 18 + len, y), ink);
      }
    } else {
      // roll end caps
      final cap = Paint()..color = const Color(0xFFCDB070);
      c.drawOval(Rect.fromCenter(center: Offset(-pageW / 2, 0), width: 26, height: 36), cap);
      c.drawOval(Rect.fromCenter(center: Offset(pageW / 2, 0), width: 26, height: 36), cap);
    }
    // cord
    if (cord > 0) {
      final cp = Paint()..color = const Color(0xFF7A4B1E)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
      c.drawLine(Offset(0, -pageH / 2 - 2), Offset(0, -pageH / 2 + (pageH + 4) * cord), cp);
      c.drawLine(Offset(-pageW * 0.18 * cord, 0), Offset(pageW * 0.18 * cord, 0), cp);
    }
    // wax seal
    if (seal > 0) {
      final k = seal < 0.6 ? 1.6 - seal / 0.6 * 0.7 : 0.9 + (seal - 0.6) / 0.4 * 0.1;
      c.drawCircle(Offset.zero, 21 * k, Paint()..color = const Color(0xFFB3202A));
      c.drawCircle(Offset.zero, 21 * k, Paint()..color = const Color(0xFF7A1119)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final tp = TextPainter(text: TextSpan(text: 'N', style: TextStyle(color: const Color(0xFFF2C66B), fontSize: 22 * k, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    }
    c.restore();
  }
  double _lerp(double a, double b, double x) => a + (b - a) * x;
  @override
  bool shouldRepaint(covariant _SendPainter o) => o.t != t;
}
