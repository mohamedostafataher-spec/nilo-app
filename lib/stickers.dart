import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'i18n.dart';
import 'sfx.dart';

/// Animated sound stickers. Sent as a short text code, so no upload and no storage.
/// Older app builds show the plain text code. Sounds are synthesized on the phone (no audio files).
class StickerDef {
  final String code, emoji, ar, en, anim;
  final List<double> tones;
  final double secs;
  const StickerDef(this.code, this.emoji, this.en, this.ar, this.anim, this.tones, this.secs);
}

class NiloStickers {
  static const all = <StickerDef>[
    StickerDef('camel', '🐫', 'Camel walk', 'جمل ماشي', 'sway', [196, 220, 196, 165], 0.8),
    StickerDef('shai', '🍵', 'Tea time', 'كوباية شاي', 'bounce', [523, 659, 784], 0.6),
    StickerDef('sun', '☀️', 'Good morning', 'صباح الخير', 'spin', [392, 523, 659, 784], 0.9),
    StickerDef('eye', '🧿', 'Evil eye, protect', 'ماشاء الله', 'pulse', [330, 440, 330], 0.7),
    StickerDef('heart', '❤️', 'Love', 'حب', 'beat', [262, 262, 330, 330], 0.7),
    StickerDef('laugh', '😂', 'Haha', 'هههه', 'shake', [660, 740, 660, 740, 660], 0.8),
    StickerDef('clap', '👏', 'Bravo', 'برافو', 'bounce', [800, 800, 800, 1000], 0.6),
    StickerDef('pyramid', '🔺', 'Pyramid', 'هرم', 'rise', [196, 262, 330, 392], 0.9),
    StickerDef('palm', '🌴', 'Relax', 'ريلاكس', 'sway', [330, 294, 262], 0.9),
    StickerDef('plane', '✈️', 'Safe flight', 'سفر سعيد', 'fly', [262, 330, 392, 523, 659], 1.0),
    StickerDef('falafel', '🧆', 'Tamiya!', 'طعمية', 'bounce', [440, 554, 659], 0.5),
    StickerDef('star', '🌟', 'Great', 'حلو قوي', 'pulse', [659, 880, 1175], 0.6),
  ];

  static String wire(String code) => '[[st:$code]]';
  static String? parse(String body) {
    final m = RegExp(r'^\[\[st:([a-z]{2,12})\]\]$').firstMatch(body.trim());
    if (m == null) return null;
    final c = m.group(1)!;
    return all.any((s) => s.code == c) ? c : null;
  }

  static StickerDef def(String code) => all.firstWhere((s) => s.code == code);

  static Future<void> sound(StickerDef d) => Sfx.playTones('st_${d.code}', d.tones, d.secs);

  static Future<String?> pick(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0E2A45),
      builder: (c) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('Stickers (tap to send) • ستيكرز'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true, crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
            children: [for (final d in all) InkWell(
              onTap: () => Navigator.pop(c, d.code),
              child: Container(
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(height: 2),
                  Text(Ui.lang == 'ar' ? d.ar : d.en, style: const TextStyle(fontSize: 10, color: Colors.white70), textAlign: TextAlign.center),
                ]),
              ),
            )],
          ),
        ]),
      )),
    );
  }
}

class StickerBubble extends StatefulWidget {
  final String code;
  final bool autoSound;
  const StickerBubble({super.key, required this.code, this.autoSound = false});
  @override
  State<StickerBubble> createState() => _StickerBubbleState();
}

class _StickerBubbleState extends State<StickerBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  static final Set<String> _heard = {};

  @override
  void initState() {
    super.initState();
    _play(sound: false);
  }

  void _play({bool sound = true}) {
    _a.forward(from: 0);
    if (sound) NiloStickers.sound(NiloStickers.def(widget.code));
  }

  @override
  void dispose() { _a.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = NiloStickers.def(widget.code);
    return GestureDetector(
      onTap: _play,
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final t = Curves.easeOut.transform(_a.value);
          final w = math.sin(_a.value * math.pi * 4);
          double sc = 1, rot = 0, dx = 0, dy = 0;
          switch (d.anim) {
            case 'sway': rot = w * 0.18; dx = w * 6; break;
            case 'bounce': dy = -math.sin(_a.value * math.pi * 3).abs() * 18; break;
            case 'spin': rot = t * math.pi * 2; break;
            case 'pulse': sc = 1 + math.sin(_a.value * math.pi * 3).abs() * 0.3; break;
            case 'beat': sc = 1 + (math.sin(_a.value * math.pi * 6).abs() * 0.28); break;
            case 'shake': rot = w * 0.2; dy = -math.sin(_a.value * math.pi * 4).abs() * 6; break;
            case 'rise': dy = (1 - t) * 24; sc = 0.7 + t * 0.3; break;
            case 'fly': dx = (t - 0.5) * 60 * (1 - t); dy = -t * 14; rot = -0.35 * (1 - t); break;
          }
          return SizedBox(width: 96, height: 96, child: Center(child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(angle: rot, child: Transform.scale(scale: sc, child: Text(d.emoji, style: const TextStyle(fontSize: 64)))),
          )));
        },
      ),
    );
  }
}
