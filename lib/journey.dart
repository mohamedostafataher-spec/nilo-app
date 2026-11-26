import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'land.dart';

/// Real geography (Natural Earth land outlines), orthographic globe.
/// Stage 1: the papyrus sails down the Nile (real river course, approximate).
/// Stage 2: the camera pulls back and the papyrus is set adrift from the Nile delta into the Mediterranean.
class Pt { final double lat, lon; const Pt(this.lat, this.lon); }

const kNile = [Pt(22.0, 31.3), Pt(24.09, 32.90), Pt(25.70, 32.64), Pt(26.16, 32.72), Pt(27.18, 31.18), Pt(28.11, 30.75), Pt(29.07, 31.10), Pt(30.04, 31.24), Pt(30.9, 31.0), Pt(31.46, 30.4), Pt(32.4, 29.9)];

double _rad(double d) => d * math.pi / 180;

class GlobePainter extends CustomPainter {
  final double t; // 0..1 trip progress
  final double spin; // slow idle spin 0..1
  GlobePainter(this.t, this.spin);

  static Pt _lerp(Pt a, Pt b, double u) => Pt(a.lat + (b.lat - a.lat) * u, a.lon + (b.lon - a.lon) * u);
  static Pt _along(List<Pt> l, double u) {
    final f = u.clamp(0.0, 1.0) * (l.length - 1);
    final i = f.floor().clamp(0, l.length - 2);
    return _lerp(l[i], l[i + 1], f - i);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final e = Curves.easeInOutCubic;
    // stages: 0-0.45 Nile, 0.45-0.8 pull back, 0.8-1 drifting at sea
    final nileU = e.transform((t / 0.45).clamp(0.0, 1.0));
    final pull = e.transform(((t - 0.35) / 0.45).clamp(0.0, 1.0));
    final drift = e.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));
    const sea = [Pt(32.4, 29.9), Pt(34.5, 24.0), Pt(36.0, 10.0), Pt(36.5, -8.0), Pt(30.0, -30.0)];
    final papyrus = t < 0.45 ? _along(kNile, nileU) : _along(sea, drift);
    // camera: on the Nile near Cairo, then follows the papyrus while zooming out
    final nileCam = _lerp(const Pt(26.5, 31.5), const Pt(30.2, 31.2), nileU);
    final cam0 = t < 0.45 ? nileCam : _lerp(nileCam, papyrus, pull);
    final cam = Pt(cam0.lat, cam0.lon + (t > 0.8 ? (spin * 0 ) : 0));
    final base = math.min(s.width, s.height) * 0.46;
    final R = base * (1 + 9.0 * (1 - pull) * (1 - pull)) ; // zoomed in at start
    final c = Offset(s.width / 2, s.height / 2);

    // space
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF050E1C));
    final rnd = math.Random(7);
    final star = Paint()..color = Colors.white54;
    for (var i = 0; i < 70; i++) { canvas.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height), rnd.nextDouble() * 1.2 + .3, star); }

    final phi0 = _rad(cam.lat), lam0 = _rad(cam.lon);
    Offset? proj(double lat, double lon, [bool clampBack = true]) {
      final p = _rad(lat), l = _rad(lon) - lam0;
      final cosc = math.sin(phi0) * math.sin(p) + math.cos(phi0) * math.cos(p) * math.cos(l);
      var x = math.cos(p) * math.sin(l);
      var y = math.cos(phi0) * math.sin(p) - math.sin(phi0) * math.cos(p) * math.cos(l);
      if (cosc < 0) {
        if (!clampBack) return null;
        final n = math.sqrt(x * x + y * y);
        if (n == 0) { x = 1; y = 0; } else { x /= n; y /= n; }
      }
      return Offset(c.dx + x * R, c.dy - y * R);
    }

    // atmosphere + ocean
    final globe = Rect.fromCircle(center: c, radius: R);
    canvas.drawCircle(c, R * 1.04, Paint()..color = const Color(0xFF3FA7D6).withOpacity(.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.save();
    canvas.clipPath(Path()..addOval(globe));
    canvas.drawRect(globe, Paint()..shader = const RadialGradient(center: Alignment(-.3, -.4), radius: 1.1, colors: [Color(0xFF1C6A9A), Color(0xFF0C3B63), Color(0xFF07213F)]).createShader(globe));
    // graticule
    final grat = Paint()..color = Colors.white.withOpacity(.07)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var lat = -60; lat <= 60; lat += 30) {
      final path = Path(); var started = false;
      for (var lon = -180; lon <= 180; lon += 5) { final o = proj(lat.toDouble(), lon.toDouble(), false); if (o == null) { started = false; continue; } if (!started) { path.moveTo(o.dx, o.dy); started = true; } else { path.lineTo(o.dx, o.dy); } }
      canvas.drawPath(path, grat);
    }
    for (var lon = -180; lon < 180; lon += 30) {
      final path = Path(); var started = false;
      for (var lat = -85; lat <= 85; lat += 5) { final o = proj(lat.toDouble(), lon.toDouble(), false); if (o == null) { started = false; continue; } if (!started) { path.moveTo(o.dx, o.dy); started = true; } else { path.lineTo(o.dx, o.dy); } }
      canvas.drawPath(path, grat);
    }
    // land
    final fill = Paint()..color = const Color(0xFFD9B66A);
    final edge = Paint()..color = const Color(0xFF8A6B2F)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final poly in kLand) {
      final path = Path();
      var any = false;
      for (var i = 0; i < poly.length; i += 2) {
        final o = proj(poly[i + 1], poly[i]);
        if (o == null) continue;
        any = true;
        if (i == 0) { path.moveTo(o.dx, o.dy); } else { path.lineTo(o.dx, o.dy); }
      }
      if (!any) continue;
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
    // night shade on the limb
    canvas.drawRect(globe, Paint()..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withOpacity(.45)], stops: const [.65, 1]).createShader(globe));
    // Nile line
    final nile = Path(); var ns = false;
    for (final p in kNile) { final o = proj(p.lat, p.lon, false); if (o == null) continue; if (!ns) { nile.moveTo(o.dx, o.dy); ns = true; } else { nile.lineTo(o.dx, o.dy); } }
    canvas.drawPath(nile, Paint()..color = const Color(0xFF39A0D6)..style = PaintingStyle.stroke..strokeWidth = math.max(2.0, R / 120)..strokeCap = StrokeCap.round);
    // trail
    final trail = Path(); var ts = false;
    void addTrail(Pt p) { final o = proj(p.lat, p.lon, false); if (o == null) return; if (!ts) { trail.moveTo(o.dx, o.dy); ts = true; } else { trail.lineTo(o.dx, o.dy); } }
    if (t < 0.45) { for (var i = 0; i <= 30; i++) { addTrail(_along(kNile, nileU * i / 30)); } }
    else { for (var i = 0; i <= 30; i++) { addTrail(_along(kNile, 1.0 * i / 30)); } for (var i = 0; i <= 40; i++) { addTrail(_along(sea, drift * i / 40)); } }
    canvas.drawPath(trail, Paint()..color = const Color(0xFFFFE08A)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5));
    canvas.restore();
    canvas.drawCircle(c, R, Paint()..color = const Color(0xFF7CC8F0).withOpacity(.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // papyrus marker
    final pm = proj(papyrus.lat, papyrus.lon, false);
    if (pm != null) {
      final pulse = 1 + 0.25 * math.sin(spin * 2 * math.pi * 6);
      canvas.drawCircle(pm, 16 * pulse, Paint()..color = const Color(0xFFFFE08A).withOpacity(.25));
      final tp = TextPainter(text: const TextSpan(text: '📜', style: TextStyle(fontSize: 28)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, pm - Offset(tp.width / 2, tp.height / 2));
    }
    // Cairo label while on the Nile
    if (t < 0.5) {
      final o = proj(30.04, 31.24, false);
      if (o != null) {
        final tp = TextPainter(text: const TextSpan(text: 'القاهرة • Cairo', style: TextStyle(fontSize: 13, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)])), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, o + const Offset(12, -8));
      }
    }
  }

  @override
  bool shouldRepaint(GlobePainter o) => o.t != t || o.spin != spin;
}
