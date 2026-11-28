import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'health.dart';
import 'i18n.dart';
import 'main.dart';
import 'vr.dart';
import 'world.dart';

/// Story trip: pick a place, get a boarding pass, "fly" and land in the walkable scene. A story, not a real booking.
/// Distances use real airport coordinates (great-circle). Flight time is an estimate at 800 km/h.
class Airport {
  final String code, name, city;
  final double lat, lon;
  const Airport(this.code, this.name, this.city, this.lat, this.lon);
}

const kHomeAirports = <String, Airport>{
  'EG': Airport('CAI', 'Cairo International Airport', 'Cairo', 30.1219, 31.4056),
  'US': Airport('JFK', 'John F. Kennedy International Airport', 'New York', 40.6413, -73.7781),
  'GB': Airport('LHR', 'London Heathrow Airport', 'London', 51.4700, -0.4543),
  'DE': Airport('FRA', 'Frankfurt Airport', 'Frankfurt', 50.0379, 8.5622),
  'FR': Airport('CDG', 'Paris Charles de Gaulle Airport', 'Paris', 49.0097, 2.5479),
  'IT': Airport('FCO', 'Rome Fiumicino Airport', 'Rome', 41.8003, 12.2389),
  'ES': Airport('MAD', 'Madrid Barajas Airport', 'Madrid', 40.4983, -3.5676),
  'TR': Airport('IST', 'Istanbul Airport', 'Istanbul', 41.2753, 28.7519),
  'SA': Airport('RUH', 'King Khalid International Airport', 'Riyadh', 24.9578, 46.6989),
  'AE': Airport('DXB', 'Dubai International Airport', 'Dubai', 25.2532, 55.3657),
  'IN': Airport('DEL', 'Indira Gandhi International Airport', 'Delhi', 28.5562, 77.1000),
  'JP': Airport('HND', 'Tokyo Haneda Airport', 'Tokyo', 35.5494, 139.7798),
  'BR': Airport('GRU', 'Sao Paulo Guarulhos Airport', 'Sao Paulo', -23.4356, -46.4731),
};
const kCdg = Airport('CDG', 'Paris Charles de Gaulle Airport', 'Paris', 49.0097, 2.5479);
const kFco = Airport('FCO', 'Rome Fiumicino Airport', 'Rome', 41.8003, 12.2389);
/// Arrival airport, the walkable airport pack to open, and the country name, by destination country.
const kArrival = <String, List<dynamic>>{
  'FR': [kCdg, 49.009, 2.559, 'France'],
  'IT': [kFco, 41.800, 12.250, 'Italy'],
};

double kmBetween(double la1, double lo1, double la2, double lo2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final a = math.pow(math.sin(rad(la2 - la1) / 2), 2) + math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(rad(lo2 - lo1) / 2), 2);
  return 2 * r * math.asin(math.sqrt(a.toDouble()));
}

class TripPage extends StatefulWidget {
  const TripPage({super.key});
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  List places = [];
  String q = '';
  bool busy = true;
  String err = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('https://mohamedostafataher-spec.github.io/nilo-dl/packs/index.json')).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) places = (jsonDecode(utf8.decode(r.bodyBytes)) as List)..sort((a, b) => a[3].toString().compareTo(b[3].toString()));
      else err = L('Could not load places. Try again.');
    } catch (e, st) { Health.log(e, st); err = L('Could not load places. Check your connection.'); }
    if (mounted) setState(() => busy = false);
  }

  String _cc(List p) => p.length > 4 ? p[4].toString() : 'FR';
  String _country(List p) => (kArrival[_cc(p)] ?? kArrival['FR']!)[3] as String;

  @override
  Widget build(BuildContext context) {
    final list = places.where((p) => q.isEmpty || p[3].toString().toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Trip • رحلة')), backgroundColor: kBg),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Text(L('France and Italy: ${places.length} real places from OpenStreetMap. More countries are coming. • فرنسا وإيطاليا'), style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: L('Search a place • دور على مكان'), border: const OutlineInputBorder()))),
        if (busy) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(err)),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
          final p = list[i];
          return ListTile(
            leading: const Icon(Icons.flight_takeoff),
            title: Text(p[3].toString()),
            subtitle: Text(_country(p)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassPage(cc: _cc(p), name: p[3].toString(), lat: (p[1] as num).toDouble(), lon: (p[2] as num).toDouble()))),
          );
        })),
      ]),
    );
  }
}

class BoardingPassPage extends StatefulWidget {
  final String name, cc;
  final double lat, lon;
  const BoardingPassPage({super.key, this.cc = 'FR', required this.name, required this.lat, required this.lon});
  @override
  State<BoardingPassPage> createState() => _BoardingPassPageState();
}

class _BoardingPassPageState extends State<BoardingPassPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  bool flying = false;
  Airport get from => kHomeAirports[Passport.country] ?? kHomeAirports['EG']!;
  bool get knownHome => kHomeAirports.containsKey(Passport.country);

  @override
  void dispose() { _a.dispose(); super.dispose(); }

  List<dynamic> get arr => kArrival[widget.cc] ?? kArrival['FR']!;
  Airport get dest => arr[0] as Airport;
  double get km => kmBetween(from.lat, from.lon, dest.lat, dest.lon);

  Future<void> _fly() async {
    setState(() => flying = true);
    HapticFeedback.mediumImpact();
    await _a.forward();
    if (!mounted) return;
    Passport.addStamp('trip-${widget.cc}');
    Passport.addStamp('word-${widget.cc}');
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LandingPage(cc: widget.cc, name: widget.name, lat: widget.lat, lon: widget.lon)));
  }

  @override
  Widget build(BuildContext context) {
    final hours = km / 800;
    final h = hours.floor(), m = ((hours - h) * 60).round();
    final nick = Passport.nickname.isEmpty ? L('Traveler') : Passport.nickname;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Boarding pass • بطاقة صعود')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(18), border: Border.all(color: kGreen.withOpacity(.6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NILO STORY FLIGHT', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(from.code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)), Text(from.city, style: const TextStyle(color: Colors.white70))])),
              const Icon(Icons.flight, size: 30),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(dest.code, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)), Text(dest.city, style: const TextStyle(color: Colors.white70))])),
            ]),
            const Divider(height: 28),
            Text(L('Passenger • المسافر'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
            Text(nick, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(L('Destination • الوجهة'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
            Text('${widget.name}, ${arr[3]}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('${from.name} → ${dest.name}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Text('${km.round()} km • about ${h}h ${m.toString().padLeft(2, '0')}m at 800 km/h (estimate)', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 10),
        Text(L('A story trip, not a real booking. Distance is the great-circle line between the two real airports.${knownHome ? '' : ' Your home airport is a default (Cairo) until more airports are added.'}'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 16),
        if (flying) SizedBox(height: 120, child: AnimatedBuilder(animation: _a, builder: (_, __) => CustomPaint(painter: _FlightPainter(_a.value), size: const Size(double.infinity, 120)))),
        if (!flying) ...[
          SizedBox(height: 52, child: FilledButton.icon(onPressed: _fly, icon: const Icon(Icons.flight_takeoff), label: Text(L('Take off • انطلق')))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Share.share('Travel with me to ${widget.name} in Nilo. Download: https://mohamedostafataher-spec.github.io/nilo-dl/'),
            icon: const Icon(Icons.group_add), label: Text(L('Invite a friend to travel together • ادعو صاحبك'))),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(L('Opens your share sheet. Nothing is sent unless you choose a person.'), style: const TextStyle(fontSize: 11, color: Colors.white54))),
        ],
      ]),
    );
  }
}

class _FlightPainter extends CustomPainter {
  final double t;
  _FlightPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final line = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path()..moveTo(20, s.height - 20)..quadraticBezierTo(s.width / 2, -40, s.width - 20, s.height - 20);
    c.drawPath(path, line);
    final m = path.computeMetrics().first;
    final tan = m.getTangentForOffset(m.length * t);
    if (tan != null) {
      c.save();
      c.translate(tan.position.dx, tan.position.dy);
      c.rotate(-tan.angle);
      final tp = TextPainter(text: const TextSpan(text: '✈', style: TextStyle(fontSize: 30, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
  }
  @override
  bool shouldRepaint(_FlightPainter o) => o.t != t;
}


/// Arrival screen after the story flight: a sign with the real airport name, then the walkable airport area or the chosen place.
class LandingPage extends StatelessWidget {
  final String name, cc; final double lat, lon;
  const LandingPage({super.key, this.cc = 'FR', required this.name, required this.lat, required this.lon});
  List<dynamic> get arr => kArrival[cc] ?? kArrival['FR']!;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A4A),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.flight_land, color: Colors.white70, size: 64),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(color: const Color(0xFFFFC400), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87, width: 3)),
          child: Column(children: [
            Text('WELCOME TO ${(arr[3] as String).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2, color: Colors.black87)),
            const SizedBox(height: 6),
            Text('${(arr[0] as Airport).name} (${(arr[0] as Airport).code})', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black87)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(L('Story flight, not a real booking. • رحلة قصة مش حجز حقيقي.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VrPage(scene: 'osm', title: name, lat: lat, lon: lon))),
          child: Text(L('Go to $name • روح على المكان')),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VrPage(scene: 'osm', title: (arr[0] as Airport).name, lat: arr[1] as double, lon: arr[2] as double))),
          child: Text(L('Walk around the airport (real runway and taxiway layout) • اتمشى في المطار'), textAlign: TextAlign.center),
        ),
      ]))),
    );
  }
}
