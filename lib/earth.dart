import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'i18n.dart';

/// Earth view. Free imagery only:
///  - NASA GIBS (MODIS Terra true colour, daily, about 250 m per pixel): open NASA data, no key.
///  - EOX Sentinel-2 cloudless 2016 (10 m, CC BY 4.0): contains modified Copernicus Sentinel data 2016.
/// Day and night shading is computed on the phone from the clock. No user location is used or stored.
class EarthPage extends StatefulWidget {
  const EarthPage({super.key});
  @override
  State<EarthPage> createState() => _EarthPageState();
}

class _EarthPageState extends State<EarthPage> {
  final _map = MapController();
  int layer = 0; // 0 NASA daily, 1 Sentinel-2 detail, 2 NASA Blue Marble
  bool night = true;

  String get _date {
    final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  TileLayer _tiles() {
    switch (layer) {
      case 1:
        return TileLayer(
          urlTemplate: 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless_3857/default/g/{z}/{y}/{x}.jpg',
          maxNativeZoom: 13, userAgentPackageName: 'app.nilo.nilo_app',
        );
      case 2:
        return TileLayer(
          urlTemplate: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/BlueMarble_ShadedRelief_Bathymetry/default/GoogleMapsCompatible_Level8/{z}/{y}/{x}.jpeg',
          maxNativeZoom: 8, userAgentPackageName: 'app.nilo.nilo_app',
        );
      default:
        return TileLayer(
          urlTemplate: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_CorrectedReflectance_TrueColor/default/$_date/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg',
          maxNativeZoom: 9, userAgentPackageName: 'app.nilo.nilo_app',
        );
    }
  }

  /// Night side polygon from the sun position (approximate, good to about a degree).
  List<LatLng> _nightPolygon() {
    final now = DateTime.now().toUtc();
    final n = now.difference(DateTime.utc(now.year, 1, 1)).inDays + 1;
    final decl = -23.44 * math.cos(2 * math.pi / 365 * (n + 10)) * math.pi / 180;
    final hours = now.hour + now.minute / 60.0;
    final sunLon = -(hours - 12) * 15.0; // degrees east
    final pts = <LatLng>[];
    final t = math.tan(decl == 0 ? 1e-6 : decl);
    for (var lon = -180; lon <= 180; lon += 3) {
      final dl = (lon - sunLon) * math.pi / 180;
      final lat = math.atan(-math.cos(dl) / t) * 180 / math.pi;
      pts.add(LatLng(lat.clamp(-85.0, 85.0), lon.toDouble()));
    }
    final pole = decl > 0 ? -85.0 : 85.0;
    pts.add(LatLng(pole, 180));
    pts.add(LatLng(pole, -180));
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final names = [L('NASA daily'), L('Sentinel-2 detail'), L('Blue Marble')];
    return Scaffold(
      appBar: AppBar(title: Text(L('Earth today')), backgroundColor: const Color(0xFF0B1F33)),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(25, 25),
            initialZoom: 2.0,
            minZoom: 1.5,
            maxZoom: layer == 1 ? 13 : (layer == 2 ? 8 : 9),
            backgroundColor: const Color(0xFF050E1A),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            if (layer == 0) TileLayer(
              urlTemplate: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/BlueMarble_ShadedRelief_Bathymetry/default/GoogleMapsCompatible_Level8/{z}/{y}/{x}.jpeg',
              maxNativeZoom: 8, userAgentPackageName: 'app.nilo.nilo_app',
            ),
            _tiles(),
            if (night) PolygonLayer(polygons: [Polygon(points: _nightPolygon(), color: const Color(0x99000820), borderStrokeWidth: 1.5, borderColor: const Color(0x88FFD27A))]),
          ],
        ),
        Positioned(
          left: 10, right: 10, top: 10,
          child: Wrap(spacing: 8, runSpacing: 6, children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(label: Text(names[i]), selected: layer == i, onSelected: (_) => setState(() => layer = i)),
            FilterChip(label: Text(L('Day and night')), selected: night, onSelected: (v) => setState(() => night = v)),
          ]),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: SafeArea(top: false, child: Text(
              layer == 1
                  ? 'Imagery: EOX Sentinel-2 cloudless 2016, contains modified Copernicus Sentinel data 2016, CC BY 4.0 (cloudless.eox.at).'
                  : 'Imagery: NASA GIBS / EOSDIS, ${layer == 0 ? 'MODIS Terra true colour, $_date (UTC)' : 'Blue Marble'}. Night shading is computed on your phone. Your location is not used.',
              style: const TextStyle(fontSize: 11, color: Colors.white70), textAlign: TextAlign.center)),
          ),
        ),
      ]),
    );
  }
}
