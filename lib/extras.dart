import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'screens.dart';

const kNavy = Color(0xFF0E2A47);
const kTeal = Color(0xFF18A3A0);

/// Fade + slide transition used for every screen push.
Route<T> niloRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// The Nilo mark drawn in code: sun, pyramid, Nile waves. [t] animates 0..1.
class LogoPainter extends CustomPainter {
  final double t;
  LogoPainter(this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 512;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(112 * u)));
    canvas.drawRect(Offset.zero & s, Paint()..color = kNavy);
    final rise = (1 - Curves.easeOutCubic.transform(t.clamp(0.0, 1.0))) * 90 * u;
    canvas.drawCircle(Offset(256 * u, 228 * u + rise), 122 * u, Paint()..color = const Color(0xFFE0A93B));
    canvas.drawCircle(
        Offset(256 * u, 228 * u + rise),
        146 * u,
        Paint()
          ..color = const Color(0xFFE0A93B).withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * u);
    final pyr = Path()
      ..moveTo(76 * u, 372 * u)
      ..lineTo(256 * u, 150 * u)
      ..lineTo(436 * u, 372 * u)
      ..close();
    canvas.drawPath(pyr, Paint()..color = kNavy);
    final shade = Path()
      ..moveTo(256 * u, 150 * u)
      ..lineTo(436 * u, 372 * u)
      ..lineTo(256 * u, 372 * u)
      ..close();
    canvas.drawPath(shade, Paint()..color = const Color(0xFF071A2E));
    canvas.drawPath(
        Path()
          ..moveTo(76 * u, 372 * u)
          ..lineTo(256 * u, 150 * u)
          ..lineTo(436 * u, 372 * u),
        Paint()
          ..color = const Color(0xFFF3DCA0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * u
          ..strokeJoin = StrokeJoin.round);
    final bands = <List<Object>>[
      [372.0, kTeal],
      [404.0, const Color(0xFF117F84)],
      [446.0, const Color(0xFF0B5F6B)],
    ];
    for (var i = 0; i < bands.length; i++) {
      final y = (bands[i][0] as double) * u;
      final ph = t * 2 * math.pi * 2 + i;
      final p = Path()..moveTo(0, s.height)..lineTo(0, y);
      for (double x = 0; x <= s.width; x += 4) {
        p.lineTo(x, y + math.sin(x / (64 * u) * math.pi + ph) * 8 * u);
      }
      p..lineTo(s.width, s.height)..close();
      canvas.drawPath(p, Paint()..color = bands[i][1] as Color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter o) => o.t != t;
}

/// Splash: logo rises, waves move, name fades in, then onboarding (first run) or home.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool('onboarded') ?? false;
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(niloRoute(seen ? const TouristHome() : const OnboardingPage()));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 160, height: 160, child: CustomPaint(painter: LogoPainter(_c.value))),
              const SizedBox(height: 18),
              Opacity(
                opacity: Curves.easeIn.transform(((_c.value - 0.4) / 0.6).clamp(0.0, 1.0)),
                child: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('نيلو  |  NILO', style: TextStyle(color: kNavy, fontSize: 30, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      );
}

/// First-run tutorial (4 pages, skippable).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;
  static const _pages = <List<Object>>[
    [Icons.translate, 'Speak any language', 'اتكلم بأي لغة',
        'Type, talk or import audio. Nilo translates between 52 languages and can read it out loud. Machine translation can be wrong, so check anything important.',
        'اكتب أو اتكلم أو ضيف ملف صوت. نيلو يترجم بين 52 لغة ويقرأها بصوت. الترجمة الآلية ممكن تغلط، راجع أي حاجة مهمة.'],
    [Icons.photo_camera, 'Point the camera', 'صوّر المنيو واللافتة',
        'Take a photo of a menu or a sign and get it translated. Use Face to face when you talk with someone next to you.',
        'صوّر منيو أو لافتة واتترجم. وفي وجهاً لوجه، الشاشة تتقسم عشان تتكلم مع اللي قدامك.'],
    [Icons.shield, 'Stay safe, pay fair', 'أمان وسعر عادل',
        'Price card, taxi checklist, ready phrases and emergency numbers with their sources and dates. Your medical card stays on this phone.',
        'ورقة أسعار وقايمة تاكسي وجمل جاهزة وأرقام طوارئ بمصادرها وتواريخها. الكارت الطبي بيفضل على موبايلك.'],
    [Icons.account_balance, 'Official services', 'خدمات رسمية',
        'Links to the official e-visa, museum tickets and trains pages. Nilo is not affiliated with them, it only opens their own sites.',
        'روابط لصفحات التأشيرة والمتاحف والقطارات الرسمية. نيلو مش تابع لهم، بيفتح مواقعهم بس.'],
  ];

  Future<void> _done() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarded', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(niloRoute(const TouristHome()));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _done, child: const Text('Skip • تخطي', style: TextStyle(color: Colors.white70))),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, k) {
                final pg = _pages[k];
                return AnimatedBuilder(
                  animation: _pc,
                  builder: (_, __) {
                    double d = 0;
                    if (_pc.hasClients && _pc.position.haveDimensions) d = ((_pc.page ?? k.toDouble()) - k).abs().clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - d,
                      child: Transform.translate(
                        offset: Offset(0, 40 * d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              width: 120, height: 120,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: kGreen.withOpacity(0.15), border: Border.all(color: kGreen, width: 3)),
                              child: Icon(pg[0] as IconData, size: 56, color: kGreen),
                            ),
                            const SizedBox(height: 28),
                            Text(pg[1] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(pg[2] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: kGreen)),
                            const SizedBox(height: 18),
                            Directionality(textDirection: TextDirection.ltr, child: Text(pg[3] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.4))),
                            const SizedBox(height: 10),
                            Text(pg[4] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5)),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < _pages.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                width: k == _i ? 22 : 8, height: 8,
                decoration: BoxDecoration(color: k == _i ? kGreen : Colors.white30, borderRadius: BorderRadius.circular(4)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: kNavy),
                onPressed: () => last ? _done() : _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
                child: Text(last ? 'Start • ابدأ' : 'Next • التالي', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Official services: plain links to real official sites. No integration, no partnership.
class OfficialPage extends StatelessWidget {
  const OfficialPage({super.key});
  static const _items = <List<String>>[
    ['e-Visa portal', 'بوابة التأشيرة الإلكترونية', 'Official Egypt e-Visa portal. The portal says to apply at least 7 days before departure.', 'https://www.visa2egypt.gov.eg/eVisa/Home', 'visa2egypt.gov.eg'],
    ['Museum & site tickets', 'تذاكر المتاحف والمواقع الأثرية', 'Ministry of Tourism and Antiquities. Online booking for sites and museums (Egypt Independent, 9 Sep 2024).', 'https://egymonuments.gov.eg/en', 'egymonuments.gov.eg'],
    ['Egyptian National Railways', 'السكك الحديدية المصرية', 'Official ENR site for train info and booking.', 'https://www.enr.gov.eg/En/', 'enr.gov.eg'],
    ['Experience Egypt', 'تجربة مصر', 'Egypt tourism board site: entry visa rules, useful information.', 'https://www.experienceegypt.eg/en/usefulinfo', 'experienceegypt.eg'],
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Official services • خدمات رسمية'), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          const Text('Nilo is not affiliated with these services. Each button opens the official site in your browser. Links checked 26 Nov 2026. Check prices and rules on the site itself.\nنيلو مش تابع للجهات دي، الزر بيفتح موقعها الرسمي. الروابط اتراجعت 26 نوفمبر 2026.',
              style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
          const SizedBox(height: 12),
          for (final i in _items)
            Card(
              color: const Color(0xFF1F2429),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                title: Text('${i[0]}\n${i[1]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${i[2]}\n${i[4]}', style: const TextStyle(fontSize: 12, color: Colors.white70))),
                trailing: const Icon(Icons.open_in_new, color: kGreen),
                onTap: () => openUrl(i[3]),
              ),
            ),
        ]),
      );
}
