import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'sfx.dart';

/// Hand-drawn Egyptian-style icons (no asset files, so no size cost).
enum NiloIcon { nile, messages, send, stories, passport }

class NiloIconPainter extends CustomPainter {
  final NiloIcon icon; final Color color; final double t;
  NiloIconPainter(this.icon, this.color, this.t);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final f = Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.fill;
    switch (icon) {
      case NiloIcon.nile: // felucca: curved hull + triangular sail
        final hull = Path()..moveTo(w * .08, h * .70)..quadraticBezierTo(w * .5, h * .95, w * .92, h * .70)..close();
        c.drawPath(hull, f); c.drawPath(hull, p);
        c.drawLine(Offset(w * .48, h * .70), Offset(w * .48, h * .10), p);
        final sail = Path()..moveTo(w * .52, h * .14)..lineTo(w * .90, h * .62)..lineTo(w * .52, h * .62)..close();
        c.drawPath(sail, f); c.drawPath(sail, p);
        break;
      case NiloIcon.messages: // scroll with a speech tail
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(w * .1, h * .15, w * .8, h * .55), const Radius.circular(8));
        c.drawRRect(r, f); c.drawRRect(r, p);
        final tail = Path()..moveTo(w * .3, h * .70)..lineTo(w * .26, h * .90)..lineTo(w * .48, h * .70);
        c.drawPath(tail, p);
        c.drawLine(Offset(w * .26, h * .35), Offset(w * .74, h * .35), p);
        c.drawLine(Offset(w * .26, h * .50), Offset(w * .60, h * .50), p);
        break;
      case NiloIcon.send: // papyrus roll with a feather stroke
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * .22, h * .18, w * .56, h * .64), const Radius.circular(4));
        c.drawRRect(body, f); c.drawRRect(body, p);
        c.drawOval(Rect.fromLTWH(w * .14, h * .10, w * .72, h * .16), p);
        c.drawOval(Rect.fromLTWH(w * .14, h * .74, w * .72, h * .16), p);
        c.drawLine(Offset(w * .36, h * .44), Offset(w * .64, h * .44), p);
        c.drawLine(Offset(w * .36, h * .58), Offset(w * .56, h * .58), p);
        break;
      case NiloIcon.stories: // open book / pyramid-page
        final l = Path()..moveTo(w * .5, h * .25)..quadraticBezierTo(w * .28, h * .12, w * .08, h * .22)..lineTo(w * .08, h * .78)..quadraticBezierTo(w * .28, h * .68, w * .5, h * .80)..close();
        final r2 = Path()..moveTo(w * .5, h * .25)..quadraticBezierTo(w * .72, h * .12, w * .92, h * .22)..lineTo(w * .92, h * .78)..quadraticBezierTo(w * .72, h * .68, w * .5, h * .80)..close();
        c.drawPath(l, f); c.drawPath(r2, f); c.drawPath(l, p); c.drawPath(r2, p);
        break;
      case NiloIcon.passport: // passport with a round stamp
        final b = RRect.fromRectAndRadius(Rect.fromLTWH(w * .20, h * .08, w * .60, h * .84), const Radius.circular(6));
        c.drawRRect(b, f); c.drawRRect(b, p);
        c.drawCircle(Offset(w * .5, h * .42), w * .15, p);
        c.drawLine(Offset(w * .50, h * .27), Offset(w * .50, h * .57), p);
        c.drawLine(Offset(w * .35, h * .42), Offset(w * .65, h * .42), p);
        c.drawLine(Offset(w * .34, h * .72), Offset(w * .66, h * .72), p);
        break;
    }
  }
  @override
  bool shouldRepaint(covariant NiloIconPainter o) => o.icon != icon || o.color != color || o.t != t;
}

/// Floating rounded bottom bar with a raised centre "send papyrus" button.
/// Slots: 0 Nile, 1 Messages, centre = send, 2 Stories hub, 3 Passport.
class NiloNavBar extends StatelessWidget {
  final int index; final ValueChanged<int> onTab; final VoidCallback onSend;
  const NiloNavBar({super.key, required this.index, required this.onTab, required this.onSend});

  @override
  Widget build(BuildContext context) {
    const items = [
      [NiloIcon.nile, 'النيل'],
      [NiloIcon.messages, 'رسايل'],
      [NiloIcon.stories, 'حكاياتي'],
      [NiloIcon.passport, 'جواز'],
    ];
    Widget slot(int i) {
      final sel = index == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { HapticFeedback.selectionClick(); Sfx.play('tab'); onTab(i); },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: sel ? 1 : 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (_, v, __) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Transform.translate(
                offset: Offset(0, -4 * v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.20 * v), borderRadius: BorderRadius.circular(18)),
                  child: SizedBox(width: 26 + 2 * v, height: 26 + 2 * v, child: CustomPaint(painter: NiloIconPainter(items[i][0] as NiloIcon, Color.lerp(Colors.white54, kGreen, v)!, v))),
                ),
              ),
              Text(items[i][1] as String, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: Color.lerp(Colors.white54, kGreen, v))),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SizedBox(
          height: 82,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xF20B1F33),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x44D9A441)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Row(children: [slot(0), slot(1), const SizedBox(width: 76), slot(2), slot(3)]),
            ),
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); onSend(); },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2C66B), kGreen]),
                      border: Border.all(color: kBg, width: 4),
                      boxShadow: const [BoxShadow(color: Color(0x88D9A441), blurRadius: 14)],
                    ),
                    child: Padding(padding: const EdgeInsets.all(14), child: CustomPaint(painter: NiloIconPainter(NiloIcon.send, kBg, 1))),
                  ),
                  const SizedBox(height: 2),
                  const Text('ابعت بردية', style: TextStyle(fontSize: 10, color: kGreen, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
