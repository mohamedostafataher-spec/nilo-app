import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport, kWorld;

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
    try { stamps = (jsonDecode(p.getString('globe_stamps') ?? '[]') as List).length; } catch (_) {}
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
            height: 320,
            child: LayoutBuilder(builder: (_, box) {
              final w = box.maxWidth;
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _HomePainter(look, night, trees))),
                _slot('sky', w * 0.70, 12, 34),
                _slot('left', w * 0.03, 190, 42),
                _slot('right', w * 0.80, 215, 38),
                _slot('door', w * 0.49, 205, 26),
                _slot('window', w * 0.27, 150, 26),
              ]);
            }),
          ),
        ),
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

class _HomePainter extends CustomPainter {
  final _Look look;
  final bool night;
  final int trees;
  _HomePainter(this.look, this.night, this.trees);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final sky = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: night ? [const Color(0xFF0B1230), const Color(0xFF2A3A6B)] : [const Color(0xFF4BA8E8), const Color(0xFFBFE4F7)]).createShader(Rect.fromLTWH(0, 0, w, h));
    c.drawRect(Rect.fromLTWH(0, 0, w, h), sky);
    if (night) {
      final r = math.Random(7);
      final sp = Paint()..color = Colors.white70;
      for (var i = 0; i < 30; i++) { c.drawCircle(Offset(r.nextDouble() * w, r.nextDouble() * h * 0.5), 1.2, sp); }
      c.drawCircle(Offset(w * 0.15, 40), 14, Paint()..color = const Color(0xFFF3EBC8));
    } else {
      c.drawCircle(Offset(w * 0.15, 42), 20, Paint()..color = const Color(0xFFFFE27A));
    }
    // ground
    c.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), Paint()..color = night ? const Color(0xFF2F4A2F) : const Color(0xFF6BAA55));
    // house
    final hx = w * 0.30, hw = w * 0.40, hy = h * 0.40, hh = h * 0.34;
    final wall = Paint()..color = look.wall;
    c.drawRect(Rect.fromLTWH(hx, hy, hw, hh), wall);
    final roof = Paint()..color = look.roof;
    switch (look.style) {
      case 'flat':
        c.drawRect(Rect.fromLTWH(hx - 6, hy - 10, hw + 12, 14), roof);
        break;
      case 'pagoda':
        c.drawPath(Path()..moveTo(hx - 24, hy + 6)..quadraticBezierTo(hx + hw / 2, hy - 46, hx + hw + 24, hy + 6)..close(), roof);
        c.drawPath(Path()..moveTo(hx + hw * 0.15, hy - 22)..quadraticBezierTo(hx + hw / 2, hy - 64, hx + hw * 0.85, hy - 22)..close(), roof);
        break;
      case 'dome':
        c.drawArc(Rect.fromLTWH(hx + 8, hy - hw * 0.40, hw - 16, hw * 0.8), math.pi, math.pi, true, roof);
        c.drawRect(Rect.fromLTWH(hx - 4, hy - 6, hw + 8, 10), roof);
        break;
      default:
        c.drawPath(Path()..moveTo(hx - 10, hy + 2)..lineTo(hx + hw / 2, hy - 50)..lineTo(hx + hw + 10, hy + 2)..close(), roof);
    }
    // door and window
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx + hw / 2 - 14, hy + hh - 46, 28, 46), const Radius.circular(6)), Paint()..color = look.trim);
    c.drawRect(Rect.fromLTWH(hx + 10, hy + 22, 34, 30), Paint()..color = night ? const Color(0xFFFFE27A) : const Color(0xFFBFE4F7));
    c.drawRect(Rect.fromLTWH(hx + 10, hy + 22, 34, 30), Paint()..color = look.trim..style = PaintingStyle.stroke..strokeWidth = 2);
    // focus palms along the ground
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < math.min(trees, 12); i++) {
      tp.text = const TextSpan(text: '🌴', style: TextStyle(fontSize: 22));
      tp.layout();
      tp.paint(c, Offset(8 + i * (w - 40) / 12, h * 0.86));
    }
  }

  @override
  bool shouldRepaint(covariant _HomePainter o) => o.look != look || o.night != night || o.trees != trees;
}
