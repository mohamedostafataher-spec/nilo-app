import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'i18n.dart';
import 'main.dart';
import 'places.dart' show PlacePage, PlacesOfPage;
import 'vr.dart';
import 'world.dart' show kWorld, countryOf;

/// Papyrus journey map. Only the two country codes of a papyrus are used (sender, and the person who caught it).
/// No coordinates of any person are stored or shown. The path is a straight line over the globe between the two
/// countries' reference points, so the countries "passed" are the ones near that line. It is an illustration of the
/// route, not a tracked flight (a papyrus travels instantly on the server).
class JourneyPage extends StatefulWidget {
  final String fromCc, toCc;
  const JourneyPage({super.key, required this.fromCc, required this.toCc});
  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  List<LatLng> arc = [];
  List<List<Object>> passed = [];
  late List<Object> a, b;
  bool known = true;

  @override
  void initState() {
    super.initState();
    known = widget.fromCc.isNotEmpty;
    a = countryOf(widget.fromCc.isEmpty ? 'EG' : widget.fromCc);
    b = widget.toCc.isEmpty ? a : countryOf(widget.toCc);
    _build();
    ac.addListener(() => setState(() {}));
    ac.forward();
  }

  @override
  void dispose() { ac.dispose(); super.dispose(); }

  List<double> _vec(double la, double lo) {
    final p = la * math.pi / 180, l = lo * math.pi / 180;
    return [math.cos(p) * math.cos(l), math.cos(p) * math.sin(l), math.sin(p)];
  }

  void _build() {
    final la1 = (a[4] as num).toDouble(), lo1 = (a[5] as num).toDouble(), la2 = (b[4] as num).toDouble(), lo2 = (b[5] as num).toDouble();
    if (widget.toCc.isEmpty || widget.toCc == widget.fromCc) { arc = [LatLng(la1, lo1)]; return; }
    final v1 = _vec(la1, lo1), v2 = _vec(la2, lo2);
    final dot = (v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2]).clamp(-1.0, 1.0);
    final om = math.acos(dot), so = math.sin(om);
    double? prev;
    for (var i = 0; i <= 90; i++) {
      final t = i / 90, k1 = so.abs() < 1e-6 ? 1 - t : math.sin((1 - t) * om) / so, k2 = so.abs() < 1e-6 ? t : math.sin(t * om) / so;
      final x = k1 * v1[0] + k2 * v2[0], y = k1 * v1[1] + k2 * v2[1], z = k1 * v1[2] + k2 * v2[2];
      var lo = math.atan2(y, x) * 180 / math.pi;
      final la = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
      if (prev != null) { while (lo - prev > 180) { lo -= 360; } while (lo - prev < -180) { lo += 360; } }
      prev = lo;
      arc.add(LatLng(la, lo));
    }
    // countries near the line (reference points within about 700 km), in order along the path
    final d = const Distance();
    final hits = <List<Object>>[];
    for (final c in kWorld) {
      if (c[0] == a[0] || c[0] == b[0]) continue;
      final p = LatLng((c[4] as num).toDouble(), (c[5] as num).toDouble());
      var best = 1e12, bi = 0;
      for (var i = 0; i < arc.length; i++) {
        final q = LatLng(arc[i].latitude, ((arc[i].longitude + 540) % 360) - 180);
        final m = d.as(LengthUnit.Kilometer, p, q);
        if (m < best) { best = m; bi = i; }
      }
      if (best < 700) hits.add([c, bi]);
    }
    hits.sort((x, y) => (x[1] as int).compareTo(y[1] as int));
    passed = hits.take(6).map((h) => h[0] as List<Object>).toList();
  }

  LatLng get _plane {
    if (arc.length < 2) return arc.isEmpty ? const LatLng(0, 0) : arc.first;
    final f = Curves.easeInOut.transform(ac.value) * (arc.length - 1);
    final i = f.floor().clamp(0, arc.length - 2), t = f - i;
    return LatLng(arc[i].latitude + (arc[i + 1].latitude - arc[i].latitude) * t, arc[i].longitude + (arc[i + 1].longitude - arc[i].longitude) * t);
  }

  List<LatLng> _done() {
    if (arc.length < 2) return [];
    final f = Curves.easeInOut.transform(ac.value) * (arc.length - 1);
    final i = f.floor().clamp(0, arc.length - 1);
    return [...arc.sublist(0, i + 1), _plane];
  }

  String _name(List<Object> c) => Ui.rtl ? c[2] as String : c[1] as String;

  @override
  Widget build(BuildContext context) {
    final landed = widget.toCc.isNotEmpty && ac.value > 0.98;
    final places = kVrByCountry[widget.toCc] ?? [];
    final center = arc.isEmpty ? const LatLng(25, 25) : LatLng((arc.first.latitude + arc.last.latitude) / 2, (arc.first.longitude + arc.last.longitude) / 2);
    return Scaffold(
      appBar: AppBar(title: Text(L('Papyrus journey • رحلة البردية')), backgroundColor: kBg),
      body: Column(children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 2.2,
              initialCameraFit: arc.length > 1 ? CameraFit.coordinates(coordinates: [arc.first, arc.last], padding: const EdgeInsets.all(70), maxZoom: 5) : null,
              minZoom: 1.5, maxZoom: 7,
              backgroundColor: const Color(0xFF050E1A),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/BlueMarble_ShadedRelief_Bathymetry/default/GoogleMapsCompatible_Level8/{z}/{y}/{x}.jpeg', maxNativeZoom: 8, userAgentPackageName: 'app.nilo.nilo_app'),
              if (arc.length > 1) PolylineLayer(polylines: [
                Polyline(points: arc, strokeWidth: 2, color: Colors.white54, pattern: StrokePattern.dashed(segments: const [6, 6])),
                Polyline(points: _done(), strokeWidth: 4, color: const Color(0xFFFFD166)),
              ]),
              MarkerLayer(markers: [
                for (final c in passed) Marker(point: LatLng((c[4] as num).toDouble(), (c[5] as num).toDouble()), width: 80, height: 44, child: Column(children: [Text(c[3] as String, style: const TextStyle(fontSize: 18)), Text(_name(c), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 4, color: Colors.black)]), maxLines: 1)])),
                Marker(point: LatLng((a[4] as num).toDouble(), (a[5] as num).toDouble()), width: 90, height: 54, child: Column(children: [Text(known ? a[3] as String : '📜', style: const TextStyle(fontSize: 24)), Text(known ? _name(a) : '', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))])),
                if (arc.length > 1) Marker(point: arc.last, width: 90, height: 54, child: Column(children: [Text(b[3] as String, style: const TextStyle(fontSize: 24)), Text(_name(b), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))])),
                if (arc.length > 1) Marker(point: _plane, width: 40, height: 40, child: const Text('📜', style: TextStyle(fontSize: 28))),
              ]),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: kBg,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!known) Text(L('The sender country is not known for this papyrus.'), style: const TextStyle(color: Colors.amberAccent))
            else if (widget.toCc.isEmpty) Text('${a[3]} ${_name(a)} → ${L('Still floating: nobody caught it yet')}', style: const TextStyle(fontWeight: FontWeight.w800))
            else Text('${a[3]} ${_name(a)}  →  ${b[3]} ${_name(b)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            if (passed.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${L('Flew near')}: ${passed.map((c) => '${c[3]} ${_name(c)}').join('  ')}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
            if (landed) ...[
              const SizedBox(height: 8),
              Text('${L('Landed in')} ${b[3]} ${_name(b)}', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final p in places) ActionChip(
                  avatar: const Icon(Icons.view_in_ar, size: 16),
                  label: Text(Ui.rtl ? p[2] : p[1]),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlacePage(title: Ui.rtl ? p[2] : p[1], url: 'https://en.wikipedia.org/wiki/${p[0]}'))),
                ),
                ActionChip(avatar: const Icon(Icons.place, size: 16), label: Text(L('More places')), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesOfPage()))),
              ]),
            ],
            const SizedBox(height: 6),
            Text(L('The line is an illustration between the two countries, not a tracked flight. Only country codes are used, never locations. Map: NASA GIBS.'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}
