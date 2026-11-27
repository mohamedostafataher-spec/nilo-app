import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';
import 'main.dart';
import 'places.dart' show PlacePage;
import 'screens.dart' show openUrl;
import 'world.dart' show Passport, kWorld;

/// Nilo Globe: a 3D-looking Earth drawn on the phone (no 3D engine, one 1024x512 texture).
/// Imagery: NASA GIBS Blue Marble (open NASA data). Landmarks: Wikidata UNESCO World Heritage sites that have a
/// Wikimedia Commons photo, loaded live per country. Licences are on each photo's Commons page.
/// This is a globe with landmark cards, not a walkable world.
class GlobePage extends StatefulWidget {
  const GlobePage({super.key});
  @override
  State<GlobePage> createState() => _GlobePageState();
}

const int _nLat = 24, _nLon = 48;

class _GlobePageState extends State<GlobePage> with SingleTickerProviderStateMixin {
  static const _texUrl = 'https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=BlueMarble_ShadedRelief_Bathymetry&CRS=EPSG:4326&BBOX=-90,-180,90,180&WIDTH=1024&HEIGHT=512&FORMAT=image/jpeg&STYLES=';
  static final Map<String, Future<List<Map<String, String>>>> _lm = {};

  ui.Image? tex;
  String err = '';
  double lon0 = 31, lat0 = 22;
  double tLon = 31, tLat = 22;
  double fly = 0;
  bool _drag = false;
  final bool calm = Passport.flag('reduce_motion', false);
  List<Object>? sel;
  late final List<Object> home;
  final ValueNotifier<int> rev = ValueNotifier(0);
  late final Ticker _tick;
  Duration _last = Duration.zero;
  final List<List<Object>> hits = []; // [index into kWorld, dx, dy]

  @override
  void initState() {
    super.initState();
    final hc = Passport.country.isEmpty ? 'EG' : Passport.country;
    home = kWorld.firstWhere((w) => w[0] == hc, orElse: () => kWorld.first);
    lon0 = tLon = (home[5] as num).toDouble();
    lat0 = tLat = (home[4] as num).toDouble().clamp(-50.0, 50.0).toDouble();
    _tick = createTicker(_onTick)..start();
    SharedPreferences.getInstance().then((p) { if (mounted) setState(() => stamps = (p.getStringList('globe_stamps') ?? <String>[]).toSet()); });
    _loadTex();
  }

  @override
  void dispose() {
    _tick.dispose();
    rev.dispose();
    tex?.dispose();
    super.dispose();
  }

  Future<void> _loadTex() async {
    setState(() => err = '');
    try {
      final r = await http.get(Uri.parse(_texUrl)).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final codec = await ui.instantiateImageCodec(r.bodyBytes);
      final f = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => tex = f.image);
    } catch (_) {
      if (mounted) setState(() => err = L('Could not load the globe image. Check your connection.'));
    }
  }

  void _onTick(Duration el) {
    final dt = (el - _last).inMicroseconds / 1e6;
    _last = el;
    if (dt <= 0 || dt > 0.5) return;
    var changed = false;
    if (sel != null) {
      fly += dt / 4.0;
      if (fly > 1.5) fly = 0;
      changed = true;
      if (!_drag) {
        var d = tLon - lon0;
        while (d > 180) d -= 360;
        while (d < -180) d += 360;
        if (d.abs() > 0.05 || (tLat - lat0).abs() > 0.05) {
          lon0 += d * math.min(1.0, dt * 3);
          lat0 += (tLat - lat0) * math.min(1.0, dt * 3);
        }
      }
    } else if (!calm && !_drag) {
      lon0 += dt * 4;
      changed = true;
    }
    if (changed) rev.value++;
  }

  Set<String> stamps = {};

  Future<void> _stamp(String cc) async {
    final p = await SharedPreferences.getInstance();
    final cur = (p.getStringList('globe_stamps') ?? <String>[]).toSet();
    cur.add(cc);
    await p.setStringList('globe_stamps', cur.toList());
    if (mounted) setState(() => stamps = cur);
  }

  void _random() {
    final r = math.Random();
    final unseen = kWorld.where((w) => !stamps.contains(w[0]) && w[0] != home[0]).toList();
    final pool = unseen.isEmpty ? kWorld : unseen;
    _select(pool[r.nextInt(pool.length)]);
  }

  void _select(List<Object> w) {
    _stamp(w[0] as String);
    final a = [(home[4] as num).toDouble(), (home[5] as num).toDouble()];
    final b = [(w[4] as num).toDouble(), (w[5] as num).toDouble()];
    var dl = b[1] - a[1];
    while (dl > 180) dl -= 360;
    while (dl < -180) dl += 360;
    setState(() {
      sel = w;
      fly = 0;
      tLon = a[1] + dl / 2;
      tLat = ((a[0] + b[0]) / 2).clamp(-50.0, 50.0).toDouble();
    });
    rev.value++;
  }

  Future<List<Map<String, String>>> _landmarks(String cc) {
    return _lm.putIfAbsent(cc, () async {
      final q = 'SELECT ?s ?l ?ar ?img ?art WHERE { ?s wdt:P1435 wd:Q9259; wdt:P17 ?c; wdt:P18 ?img. ?c wdt:P297 "$cc". '
          '?s rdfs:label ?l FILTER(LANG(?l)="en") OPTIONAL{?s rdfs:label ?ar FILTER(LANG(?ar)="ar")} '
          'OPTIONAL{?art schema:about ?s; schema:isPartOf <https://en.wikipedia.org/>} } LIMIT 40';
      final r = await http.get(Uri.https('query.wikidata.org', '/sparql', {'query': q, 'format': 'json'}),
          headers: {'Accept': 'application/sparql-results+json', 'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final rows = (jsonDecode(utf8.decode(r.bodyBytes))['results']['bindings'] as List);
      final seen = <String>{};
      final out = <Map<String, String>>[];
      for (final x in rows) {
        final m = x as Map;
        String v(String k) => ((m[k] as Map?)?['value'] ?? '').toString();
        final s = v('s');
        if (s.isEmpty || !seen.add(s)) continue;
        final img = v('img');
        if (img.isEmpty) continue;
        final file = img.split('/').last;
        out.add({
          'en': v('l'),
          'ar': v('ar'),
          'img': '${img.replaceFirst('http://', 'https://')}?width=360',
          'file': 'https://commons.wikimedia.org/wiki/File:$file',
          'url': v('art'),
        });
        if (out.length >= 12) break;
      }
      return out;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = sel;
    return Scaffold(
      backgroundColor: const Color(0xFF050E1C),
      appBar: AppBar(title: Text(L('Nilo Globe • كورة نيلو')), backgroundColor: kBg),
      body: Column(children: [
        Expanded(
          child: tex == null
              ? Center(child: err.isEmpty ? const CircularProgressIndicator() : Column(mainAxisSize: MainAxisSize.min, children: [Text(err), TextButton(onPressed: _loadTex, child: Text(L('Retry')))]))
              : GestureDetector(
                  onPanStart: (_) => _drag = true,
                  onPanUpdate: (d) {
                    lon0 -= d.delta.dx * 0.35;
                    lat0 = (lat0 + d.delta.dy * 0.35).clamp(-70.0, 70.0).toDouble();
                    tLon = lon0;
                    tLat = lat0;
                    rev.value++;
                  },
                  onPanEnd: (_) => _drag = false,
                  onTapUp: (d) {
                    List<Object>? best;
                    var bd = 30.0;
                    for (final h in hits) {
                      final dd = (Offset(h[1] as double, h[2] as double) - d.localPosition).distance;
                      if (dd < bd) { bd = dd; best = kWorld[h[0] as int]; }
                    }
                    if (best != null) _select(best);
                  },
                  child: CustomPaint(painter: _GlobePainter(this), size: Size.infinite),
                ),
        ),
        if (w == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FilledButton.icon(onPressed: _random, icon: const Icon(Icons.shuffle), label: Text(L('Fly to a random country • اطلع على بلد عشوائي'))),
              const SizedBox(height: 6),
              Text('${L('Stamps')}: ${stamps.length}/${kWorld.length}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
              const SizedBox(height: 4),
              Text(L('Drag to turn the Earth. Tap a dot to fly a papyrus there and see its landmarks.\nاسحب لتدوير الأرض. دوس على نقطة عشان البردية تطير هناك وتشوف معالمها.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            ]),
          )
        else
          Container(
            height: 214,
            width: double.infinity,
            color: const Color(0xFF0E2A45),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${w[3]} ', style: const TextStyle(fontSize: 22)),
                Expanded(child: Text('${Ui.rtl ? w[2] : w[1]}   👋 ${w[8]}  🙏 ${w[9]}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => sel = null)),
              ]),
              Expanded(
                child: FutureBuilder<List<Map<String, String>>>(
                  future: _landmarks(w[0] as String),
                  builder: (c, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                    if (snap.hasError) return Center(child: Text(L('Could not load landmarks. Check your connection.')));
                    final items = snap.data ?? [];
                    if (items.isEmpty) return Center(child: Text(L('No landmark with a free photo found for this country yet.\nمفيش معلم بصورة حرة للبلد دي لسه.'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)));
                    return ListView(scrollDirection: Axis.horizontal, children: [
                      for (final it in items)
                        GestureDetector(
                          onTap: () => it['url']!.isNotEmpty
                              ? Navigator.push(context, MaterialPageRoute(builder: (_) => PlacePage(title: Ui.rtl && it['ar']!.isNotEmpty ? it['ar']! : it['en']!, url: it['url']!)))
                              : openUrl(it['file']!),
                          child: Container(
                            width: 132,
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 132, child: Image.network(it['img']!, fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, __, ___) => Container(color: Colors.black26))))),
                              const SizedBox(height: 3),
                              Text(Ui.rtl && it['ar']!.isNotEmpty ? it['ar']! : it['en']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ]);
                  },
                ),
              ),
              Text(L('Landmarks: Wikidata (UNESCO World Heritage). Photos: Wikimedia Commons, licence and author on each photo page. Imagery: NASA GIBS. A globe with landmark cards, not a walkable world.'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.white38)),
            ]),
          ),
      ]),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final _GlobePageState s;
  _GlobePainter(this.s) : super(repaint: s.rev);

  static final Float32List _uv = _buildUv();
  static final Float32List _lat = _buildAngles(true);
  static final Float32List _lon = _buildAngles(false);
  static final Map<String, TextPainter> _tp = {};

  static Float32List _buildUv() {
    final f = Float32List((_nLat + 1) * (_nLon + 1) * 2);
    var k = 0;
    for (var i = 0; i <= _nLat; i++) {
      for (var j = 0; j <= _nLon; j++) {
        f[k++] = j / _nLon * 1024;
        f[k++] = i / _nLat * 512;
      }
    }
    return f;
  }

  static Float32List _buildAngles(bool lat) {
    final f = Float32List((_nLat + 1) * (_nLon + 1));
    var k = 0;
    for (var i = 0; i <= _nLat; i++) {
      for (var j = 0; j <= _nLon; j++) {
        f[k++] = lat ? (90 - i / _nLat * 180) * math.pi / 180 : (-180 + j / _nLon * 360) * math.pi / 180;
      }
    }
    return f;
  }

  static TextPainter _text(String t, double size) {
    return _tp.putIfAbsent('$t$size', () => TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout());
  }

  // world unit vector from lat/lon radians
  static List<double> _vec(double la, double lo) => [math.cos(la) * math.sin(lo), math.sin(la), math.cos(la) * math.cos(lo)];

  @override
  void paint(Canvas c, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final R = math.min(size.width, size.height) / 2 * 0.92;
    final l0 = s.lon0 * math.pi / 180, p0 = s.lat0 * math.pi / 180;
    final cl = math.cos(l0), sl = math.sin(l0), cp = math.cos(p0), sp = math.sin(p0);
    // returns [sx, sy, z]
    List<double> view(double X, double Y, double Z) {
      final x1 = X * cl - Z * sl, z1 = X * sl + Z * cl;
      final y2 = Y * cp - z1 * sp, z2 = Y * sp + z1 * cp;
      return [cx + R * x1, cy - R * y2, z2, x1 * x1 + y2 * y2];
    }

    final center = Offset(cx, cy);
    c.drawCircle(center, R * 1.1, Paint()..shader = ui.Gradient.radial(center, R * 1.1, [const Color(0x0050A0FF), const Color(0x7050A0FF), const Color(0x0050A0FF)], [0.0, 0.92, 1.0]));
    c.drawCircle(center, R, Paint()..color = const Color(0xFF0B2A4A));
    final tex = s.tex;
    if (tex != null) {
      final nv = (_nLat + 1) * (_nLon + 1);
      final pos = Float32List(nv * 2);
      final zs = Float32List(nv);
      for (var v = 0; v < nv; v++) {
        final la = _lat[v], lo = _lon[v];
        final p = view(math.cos(la) * math.sin(lo), math.sin(la), math.cos(la) * math.cos(lo));
        pos[v * 2] = p[0];
        pos[v * 2 + 1] = p[1];
        zs[v] = p[2];
      }
      final idx = Uint16List(_nLat * _nLon * 6);
      var n = 0;
      for (var i = 0; i < _nLat; i++) {
        for (var j = 0; j < _nLon; j++) {
          final a = i * (_nLon + 1) + j, b = a + 1, d = a + _nLon + 1, e = d + 1;
          if (zs[a] > -0.03 && zs[b] > -0.03 && zs[d] > -0.03) { idx[n++] = a; idx[n++] = b; idx[n++] = d; }
          if (zs[b] > -0.03 && zs[e] > -0.03 && zs[d] > -0.03) { idx[n++] = b; idx[n++] = e; idx[n++] = d; }
        }
      }
      final verts = ui.Vertices.raw(ui.VertexMode.triangles, pos, textureCoordinates: _uv, indices: Uint16List.sublistView(idx, 0, n));
      c.drawVertices(verts, BlendMode.srcOver, Paint()..shader = ImageShader(tex, TileMode.clamp, TileMode.clamp, Float64List.fromList(List<double>.generate(16, (i) => i % 5 == 0 ? 1.0 : 0.0))));
    }
    // soft light from upper left, dark limb
    c.drawCircle(center, R, Paint()..shader = ui.Gradient.radial(center + Offset(-R * 0.35, -R * 0.35), R * 1.6, [const Color(0x00000000), const Color(0x00000000), const Color(0xB0000000)], [0.0, 0.5, 1.0]));

    // pins
    s.hits.clear();
    for (var i = 0; i < kWorld.length; i++) {
      final w = kWorld[i];
      final p = view(math.cos((w[4] as num) * math.pi / 180) * math.sin((w[5] as num) * math.pi / 180), math.sin((w[4] as num) * math.pi / 180), math.cos((w[4] as num) * math.pi / 180) * math.cos((w[5] as num) * math.pi / 180));
      if (p[2] < 0.12) continue;
      final isSel = s.sel != null && s.sel![0] == w[0];
      final isHome = s.home[0] == w[0];
      c.drawCircle(Offset(p[0], p[1]), isSel || isHome ? 6 : 3.6, Paint()..color = isSel ? const Color(0xFFFFD166) : (isHome ? const Color(0xFF4DD0E1) : Colors.white));
      c.drawCircle(Offset(p[0], p[1]), isSel || isHome ? 6 : 3.6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black54);
      s.hits.add([i, p[0], p[1]]);
      if (isSel || isHome) {
        final tp = _text(w[3] as String, 18);
        tp.paint(c, Offset(p[0] - tp.width / 2, p[1] - tp.height - 6));
      }
    }

    // papyrus route
    final sel = s.sel;
    if (sel != null && sel[0] != s.home[0]) {
      final a = _vec((s.home[4] as num) * math.pi / 180, (s.home[5] as num) * math.pi / 180);
      final b = _vec((sel[4] as num) * math.pi / 180, (sel[5] as num) * math.pi / 180);
      final double dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]).clamp(-1.0, 1.0).toDouble();
      final om = math.acos(dot);
      List<double>? at(double t) {
        if (om < 1e-4) return null;
        final sn = math.sin(om);
        final k1 = math.sin((1 - t) * om) / sn, k2 = math.sin(t * om) / sn;
        final lift = 1 + 0.2 * math.sin(math.pi * t);
        final p = view((a[0] * k1 + b[0] * k2) * lift, (a[1] * k1 + b[1] * k2) * lift, (a[2] * k1 + b[2] * k2) * lift);
        return (p[2] > 0 || p[3] > 1) ? p : null;
      }

      final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..color = const Color(0xFFFFD166);
      Offset? prev;
      for (var i = 0; i <= 48; i++) {
        final p = at(i / 48);
        if (p == null) { prev = null; continue; }
        final o = Offset(p[0], p[1]);
        if (prev != null && i % 2 == 0) c.drawLine(prev, o, stroke);
        if (i % 2 == 0 || prev == null) prev = o;
      }
      final double t = s.fly.clamp(0.0, 1.0).toDouble();
      final pp = at(t);
      if (pp != null) {
        final tp = _text('📜', 26);
        tp.paint(c, Offset(pp[0] - tp.width / 2, pp[1] - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) => true;
}
