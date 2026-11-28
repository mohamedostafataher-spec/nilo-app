import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'i18n.dart';
import 'sfx.dart';

/// A papyrus arrives sealed. Tap the wax seal: it cracks (sound and animation), the scroll unrolls, then the thread opens.
class SealPage extends StatefulWidget {
  final Widget next;
  const SealPage({super.key, required this.next});
  @override
  State<SealPage> createState() => _SealPageState();
}

class _SealPageState extends State<SealPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool broken = false;

  @override
  void dispose() { _a.dispose(); super.dispose(); }

  Future<void> _break() async {
    if (broken) return;
    setState(() => broken = true);
    Sfx.playTones('seal', [180, 120, 90, 523, 659], 0.55);
    await _a.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A4A),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(child: GestureDetector(
        onTap: _break,
        child: AnimatedBuilder(
          animation: _a,
          builder: (_, __) {
            final t = _a.value;
            final open = Curves.easeInOut.transform(math.min(1.0, t * 1.2));
            final shake = broken && t < 0.25 ? math.sin(t * 90) * 4 : 0.0;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 250, height: 70 + 170 * open,
                decoration: BoxDecoration(color: const Color(0xFFE8D5A3), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)]),
                child: Stack(alignment: Alignment.center, children: [
                  if (open > 0.5) Opacity(opacity: (open - 0.5) * 2, child: const Text('𓂀', style: TextStyle(fontSize: 56, color: Color(0xFF7A5A1E)))),
                  if (t < 0.5) Transform.translate(offset: Offset(shake, 0), child: Opacity(opacity: 1 - t * 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Transform.translate(offset: Offset(-t * 60, t * 30), child: Transform.rotate(angle: -t * 1.2, child: _half(true))),
                    Transform.translate(offset: Offset(t * 60, t * 30), child: Transform.rotate(angle: t * 1.2, child: _half(false))),
                  ]))),
                ]),
              ),
              const SizedBox(height: 22),
              Text(broken ? '' : L('A papyrus arrived, sealed. Tap the seal. • بردية وصلتلك مقفولة، اضغط على الختم'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ]);
          },
        ),
      )),
    );
  }

  Widget _half(bool left) => ClipRect(child: Align(alignment: left ? Alignment.centerLeft : Alignment.centerRight, widthFactor: 0.5, child: Container(
    width: 64, height: 64,
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFD94B3D), Color(0xFF8E1E14)])),
    child: const Center(child: Text('𓂀', style: TextStyle(fontSize: 30, color: Color(0xFF5A0E08)))),
  )));
}
