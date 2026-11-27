import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import 'vr.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'world.dart' show Passport, kWorld, countryOf, CountryPickerPage;
import 'screens.dart' show openUrl;

/// Notable places per country, loaded live from Wikidata (CC0): UNESCO World Heritage sites.
/// Nothing is stored or invented by Nilo. Labels in the app language when Wikidata has one.
class PlacesOfPage extends StatefulWidget {
  const PlacesOfPage({super.key});
  @override
  State<PlacesOfPage> createState() => _PlacesOfPageState();
}

class _PlacesOfPageState extends State<PlacesOfPage> {
  String code = '';
  bool busy = false;
  String err = '';
  List<Map<String, String>> items = [];

  @override
  void initState() {
    super.initState();
    code = Passport.country.isNotEmpty ? Passport.country : 'EG';
    _load();
  }

  Future<void> _load() async {
    setState(() { busy = true; err = ''; items = []; });
    final q = 'SELECT ?s ?l ?ar ?art WHERE { ?s wdt:P1435 wd:Q9259; wdt:P17 ?c. ?c wdt:P297 "$code". '
        '?s rdfs:label ?l FILTER(LANG(?l)="en") OPTIONAL{?s rdfs:label ?ar FILTER(LANG(?ar)="ar")} '
        'OPTIONAL{?art schema:about ?s; schema:isPartOf <https://en.wikipedia.org/>} } LIMIT 60';
    try {
      final r = await http.get(Uri.https('query.wikidata.org', '/sparql', {'query': q, 'format': 'json'}),
          headers: {'Accept': 'application/sparql-results+json', 'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final rows = (jsonDecode(utf8.decode(r.bodyBytes))['results']['bindings'] as List);
      final seen = <String>{};
      final out = <Map<String, String>>[];
      for (final b in rows) {
        final id = b['s']['value'].toString();
        if (!seen.add(id)) continue;
        out.add({'en': b['l']['value'].toString(), 'ar': (b['ar']?['value'] ?? '').toString(), 'url': (b['art']?['value'] ?? '').toString()});
      }
      out.sort((a, b) => a['en']!.compareTo(b['en']!));
      if (mounted) setState(() { items = out; busy = false; });
    } catch (e) {
      if (mounted) setState(() { busy = false; err = L('Could not load. Check your connection.'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = countryOf(code);
    return Scaffold(
      appBar: AppBar(title: Text(L('Notable places • أماكن مميزة')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        ListTile(
          leading: Text(c[3] as String, style: const TextStyle(fontSize: 30)),
          title: Text(L('${c[1]} • ${c[2]}')),
          trailing: TextButton(onPressed: () async {
            final v = await Navigator.push<Object>(context, MaterialPageRoute(builder: (_) => const CountryPickerPage(stampHome: false)));
            if (v is String) { code = v; _load(); }
          }, child: Text(L('Change'))),
        ),
        Text(L('UNESCO World Heritage sites, loaded live from Wikidata (CC0). Not a complete list of places worth visiting, and some entries are regions or groups of sites. Tap to read more on Wikipedia (English).'), style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
        const SizedBox(height: 10),
        if (busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.orangeAccent)),
        if (!busy && err.isEmpty && items.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(L('No UNESCO sites found for this country in Wikidata.'))),
        for (final it in items)
          Card(
            color: const Color(0xFF12304D),
            child: ListTile(
              title: Text(Ui.rtl && it['ar']!.isNotEmpty ? it['ar']! : it['en']!),
              subtitle: Ui.rtl && it['ar']!.isNotEmpty ? Text(it['en']!, style: const TextStyle(fontSize: 11)) : null,
              trailing: it['url']!.isEmpty ? null : const Icon(Icons.open_in_new, size: 18, color: kGreen),
              onTap: it['url']!.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlacePage(title: Ui.rtl && it['ar']!.isNotEmpty ? it['ar']! : it['en']!, url: it['url']!))),
            ),
          ),
        const SizedBox(height: 12),
        Text(L('Data: Wikidata (CC0). Links: Wikipedia (CC BY-SA).'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}

/// One place: the Wikipedia summary (text CC BY-SA 4.0) and its lead image, loaded live. Nothing is stored.
/// Image licences differ per file, so the page names Wikimedia Commons and links to the article for the author and licence.
class PlacePage extends StatefulWidget {
  final String title, url;
  const PlacePage({super.key, required this.title, required this.url});
  @override
  State<PlacePage> createState() => _PlacePageState();
}

class _Pic {
  final String url, full, credit;
  _Pic(this.url, this.full, this.credit);
}

class _PlacePageState extends State<PlacePage> {
  bool busy = true;
  String text = '', img = '', err = '', wikiUrl = '', srcNote = '';
  List<_Pic> pics = [];
  String vrScene = '', bio = 'green', vrCol = 'd8c9a8';
  _Pic? pano;
  static const _ua = {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'};

  @override
  void initState() { super.initState(); wikiUrl = widget.url; _load(); }

  Future<Map> _j(Uri u) async {
    final r = await http.get(u, headers: _ua).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map;
  }

  String _plain(String h) => h.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").trim();

  _Pic? _pic(Map p, {int w = 800}) {
    final i = ((p['imageinfo'] as List?)?.first as Map?);
    if (i == null) return null;
    final m = (i['extmetadata'] as Map?) ?? {};
    String g(String k) => _plain(((m[k] as Map?)?['value'] ?? '').toString());
    final art = g('Artist'), lic = g('LicenseShortName');
    return _Pic((i['thumburl'] ?? i['url'] ?? '').toString(), (i['url'] ?? '').toString(), [if (art.isNotEmpty) art.length > 60 ? art.substring(0, 60) : art, if (lic.isNotEmpty) lic].join(' • '));
  }

  Future<void> _load() async {
    final t = Uri.parse(widget.url).pathSegments.last;
    _vrPick();
    // 1) text: Arabic Wikipedia when the app is Arabic and an Arabic article exists, else English
    try {
      final r = await _j(Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/$t'));
      text = (r['extract'] ?? '').toString();
      img = ((r['thumbnail'] as Map?)?['source'] ?? '').toString();
      srcNote = L('Text: Wikipedia (CC BY-SA 4.0), in English. Image: Wikimedia Commons; the author and licence are on the article page.');
      if (Ui.rtl) {
        try {
          final ll = await _j(Uri.https('en.wikipedia.org', '/w/api.php', {'action': 'query', 'prop': 'langlinks', 'lllang': 'ar', 'titles': t, 'format': 'json', 'redirects': '1'}));
          final pg = (ll['query']['pages'] as Map).values.first as Map;
          final at = ((pg['langlinks'] as List?)?.first as Map?)?['*']?.toString() ?? '';
          if (at.isNotEmpty) {
            final ar = await _j(Uri.https('ar.wikipedia.org', '/w/api.php', {'action': 'query', 'prop': 'extracts', 'explaintext': '1', 'exintro': '1', 'titles': at, 'format': 'json', 'redirects': '1'}));
            final ex = (((ar['query']['pages'] as Map).values.first as Map)['extract'] ?? '').toString().trim();
            if (ex.isNotEmpty) {
              text = ex;
              wikiUrl = Uri.https('ar.wikipedia.org', '/wiki/${at.replaceAll(' ', '_')}').toString();
              srcNote = L('Text: Arabic Wikipedia (CC BY-SA 4.0). Image: Wikimedia Commons; the author and licence are on the article page.');
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      err = L('Could not load. Check your connection.');
    }
    if (mounted) setState(() => busy = false);
    // 2) photos from the article (Wikimedia Commons), real files only, each with author and licence
    try {
      final r = await _j(Uri.https('en.wikipedia.org', '/w/api.php', {'action': 'query', 'generator': 'images', 'titles': t, 'gimlimit': '50', 'prop': 'imageinfo', 'iiprop': 'url|size|mime|extmetadata', 'iiurlwidth': '900', 'format': 'json', 'redirects': '1'}));
      final pages = ((r['query'] as Map?)?['pages'] as Map?)?.values.toList() ?? [];
      final bad = RegExp(r'icon|logo|flag|map|symbol|commons|pog|shackle|blank|diagram|plan', caseSensitive: false);
      for (final p in pages) {
        final i = ((p['imageinfo'] as List?)?.first as Map?);
        if (i == null || i['mime'] != 'image/jpeg' || ((i['width'] ?? 0) as num) < 800 || bad.hasMatch((p['title'] ?? '').toString())) continue;
        final pc = _pic(p as Map);
        if (pc != null && pc.url.isNotEmpty) pics.add(pc);
        if (pics.length >= 12) break;
      }
      if (mounted) setState(() {});
    } catch (_) {}
    // 3) a real wide / 360 panorama file from Commons for this place, if one exists
    try {
      final name = Uri.decodeComponent(t).replaceAll('_', ' ');
      final words = name.split(' ').where((w) => w.length > 3).map((w) => w.toLowerCase()).toList();
      final r = await _j(Uri.https('commons.wikimedia.org', '/w/api.php', {'action': 'query', 'generator': 'search', 'gsrnamespace': '6', 'gsrsearch': '$name panorama', 'gsrlimit': '15', 'prop': 'imageinfo', 'iiprop': 'url|size|mime|extmetadata', 'iiurlwidth': '4000', 'format': 'json'}));
      final pages = ((r['query'] as Map?)?['pages'] as Map?)?.values.toList() ?? [];
      Map? best;
      var bestScore = -1.0;
      for (final p in pages) {
        final i = ((p['imageinfo'] as List?)?.first as Map?);
        if (i == null || i['mime'] != 'image/jpeg') continue;
        final w = (i['width'] as num).toDouble(), h = (i['height'] as num).toDouble();
        final tt = (p['title'] ?? '').toString().toLowerCase();
        if (w < 4000 || w / h < 2.2 || !(words.isEmpty || words.any(tt.contains))) continue;
        final sc = (tt.contains('360') ? 100 : 0) + w / h;
        if (sc > bestScore) { bestScore = sc; best = p as Map; }
      }
      if (best != null) { pano = _pic(best); if (mounted) setState(() {}); }
    } catch (_) {}
  }

  double? plat, plon;

  Future<void> _vrPick() async {
    final key = Uri.parse(widget.url).pathSegments.last;
    final known = kVrScenes[key];
    String types = '', cc = '';
    try {
      final q = 'SELECT ?tl ?cc WHERE { VALUES ?art { <https://en.wikipedia.org/wiki/$key> } ?art schema:about ?s. '
          'OPTIONAL{ ?s wdt:P31 ?t. ?t rdfs:label ?tl FILTER(LANG(?tl)="en") } OPTIONAL{ ?s wdt:P17 ?c. ?c wdt:P297 ?cc } OPTIONAL{ ?s wdt:P625 ?co } } LIMIT 20';
      final r = await _j(Uri.https('query.wikidata.org', '/sparql', {'query': q, 'format': 'json'}));
      final rows = (r['results']['bindings'] as List);
      final ts = <String>{};
      for (final b in rows) {
        final tl = (b['tl']?['value'] ?? '').toString();
        if (tl.isNotEmpty) ts.add(tl);
        if (cc.isEmpty) cc = (b['cc']?['value'] ?? '').toString();
        final co = (b['co']?['value'] ?? '').toString();
        final mm = RegExp(r'Point\(([-0-9.]+) ([-0-9.]+)\)').firstMatch(co);
        if (mm != null && plat == null) { plon = double.tryParse(mm.group(1)!); plat = double.tryParse(mm.group(2)!); }
      }
      types = ts.join(' ');
    } catch (_) {}
    if (cc.isEmpty) cc = Passport.country.toUpperCase();
    vrScene = known ?? vrTemplate(types, Uri.decodeComponent(key).replaceAll('_', ' '), cc);
    const desertK = ['taj', 'giza', 'petra', 'abusimbel', 'burj', 'karnak'];
    bio = desertK.contains(known) ? 'desert' : (known == 'christ' || known == 'steppyr') ? 'tropical' : vrBiome(cc, types);
    vrCol = vrColor(cc);
    if (mounted) setState(() {});
  }

  void _open(_Pic p) => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title, maxLines: 1)),
        body: Column(children: [
          Expanded(child: InteractiveViewer(maxScale: 5, child: Center(child: Image.network(p.full.isNotEmpty ? p.url : p.url, fit: BoxFit.contain)))),
          Padding(padding: const EdgeInsets.all(10), child: Text('${L('Photo')}: Wikimedia Commons • ${p.credit}', style: const TextStyle(color: Colors.white60, fontSize: 11))),
        ]),
      )));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (img.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                const SizedBox(height: 12),
                if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.orangeAccent)),
                if (vrScene.isNotEmpty) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD9A441), foregroundColor: const Color(0xFF3B2A12), minimumSize: const Size.fromHeight(54)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VrPage(scene: vrScene, title: widget.title, biome: bio, color: vrCol))),
                    icon: const Icon(Icons.view_in_ar),
                    label: Text(L('Walk inside in 3D • تمشّى جواها 3D')),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(kVrScenes.containsKey(Uri.parse(widget.url).pathSegments.last) ? L('A stylized 3D scene drawn by Nilo, not real photography. Real photos are below.') : L('A generated 3D scene matched to this kind of place (not its real shape), in the colours of its country. Real photos are below.'), style: const TextStyle(fontSize: 11, color: Colors.white54))),
                ],
                if (plat != null && plon != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VrPage(scene: 'osm', title: widget.title, lat: plat, lon: plon))),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(L('Explore the area around it (pilot) • استكشف المنطقة حواليه (تجريبي)')),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(L('Real streets and buildings from OpenStreetMap contributors (ODbL), drawn as plain 3D shapes. Many heights are guessed and some areas are sparse. Needs internet and can take up to a minute.'), style: const TextStyle(fontSize: 11, color: Colors.white54))),
                ],
                if (pano != null) FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2A7FBA), minimumSize: const Size.fromHeight(50)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PanoPage(title: widget.title, pic: pano!))),
                  icon: const Icon(Icons.threesixty),
                  label: Text(L('Virtual visit: look around • زيارة افتراضية')),
                ),
                if (pano != null) const SizedBox(height: 12),
                if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 16, height: 1.7)),
                if (pics.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(L('Photos • صور'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: pics.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _open(pics[i]),
                        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(pics[i].url, width: 210, height: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 210, child: Icon(Icons.broken_image)))),
                      ))),
                  const SizedBox(height: 4),
                  Text(L('Tap a photo to open it big. Author and licence show there.'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: () => openUrl(wikiUrl), icon: const Icon(Icons.open_in_new), label: Text(L('Read the full article on Wikipedia'))),
                const SizedBox(height: 14),
                Text(srcNote, style: const TextStyle(fontSize: 11, color: Colors.white38, height: 1.5)),
              ]),
      );
}

/// Virtual visit: a real panorama photo from Wikimedia Commons. Drag to look around; it wraps around like a 360 view
/// when the file is a full 360 (wide files that are not full circles also wrap, which is noted in the credit line).
/// "Take a photo" saves what you see on screen through the share sheet. This is a photo panorama, not a walk-through.
class PanoPage extends StatefulWidget {
  final String title;
  final _Pic pic;
  const PanoPage({super.key, required this.title, required this.pic});
  @override
  State<PanoPage> createState() => _PanoPageState();
}

class _PanoPageState extends State<PanoPage> with SingleTickerProviderStateMixin {
  ui.Image? im;
  double off = 0;
  bool auto = true, bad = false;
  final key = GlobalKey();
  late final Ticker tk;

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) { if (auto && mounted) setState(() => off += 0.6); })..start();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse(widget.pic.url), headers: const {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 40));
      final codec = await ui.instantiateImageCodec(r.bodyBytes);
      final f = await codec.getNextFrame();
      if (mounted) setState(() => im = f.image);
    } catch (_) { if (mounted) setState(() => bad = true); }
  }

  @override
  void dispose() { tk.dispose(); super.dispose(); }

  Future<void> _shot() async {
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/nilo_visit_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: '${widget.title} • Nilo');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.title, maxLines: 1)),
        body: Column(children: [
          Expanded(
            child: im == null
                ? Center(child: bad ? Text(L('Could not load. Check your connection.')) : Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 10), Text(L('Loading the panorama...'))]))
                : GestureDetector(
                    onPanStart: (_) => auto = false,
                    onPanUpdate: (d) => setState(() => off -= d.delta.dx),
                    child: RepaintBoundary(key: key, child: CustomPaint(painter: _PanoPainter(im!, off), child: const SizedBox.expand())),
                  ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: Column(children: [
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: im == null ? null : _shot, icon: const Icon(Icons.photo_camera), label: Text(L('Take a photo • صوّر')))),
              const SizedBox(width: 8),
              IconButton(onPressed: () => setState(() => auto = !auto), icon: Icon(auto ? Icons.pause_circle : Icons.play_circle), iconSize: 36),
            ]),
            const SizedBox(height: 6),
            Text('${L('Drag to look around.')} ${L('Photo')}: Wikimedia Commons • ${widget.pic.credit}. ${L('A real panorama photo, not a walk-through.')}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ]),
      );
}

class _PanoPainter extends CustomPainter {
  final ui.Image im;
  final double off;
  _PanoPainter(this.im, this.off);
  @override
  void paint(Canvas c, Size s) {
    final k = s.height / im.height; // fit the height, wrap sideways
    final tw = im.width * k;
    final o = ((off % tw) + tw) % tw;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var x = -o; x < s.width; x += tw) {
      c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), Rect.fromLTWH(x, 0, tw + 1, s.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant _PanoPainter o) => o.off != off || o.im != im;
}

/// Real Egyptian landmarks on the home scene. Photos and titles come live from Wikipedia (images are from Wikimedia Commons).
/// A landmark is shown only when its photo really loaded. Tapping opens the place page with text, photo and credits.
class LandmarkStrip extends StatefulWidget {
  const LandmarkStrip({super.key});
  @override
  State<LandmarkStrip> createState() => _LandmarkStripState();
}

class _LandmarkStripState extends State<LandmarkStrip> {
  static const _items = [
    ['Giza_pyramid_complex', 'Giza Pyramids', 'أهرامات الجيزة'],
    ['Abu_Simbel_temples', 'Abu Simbel', 'أبو سمبل'],
    ['Karnak', 'Karnak', 'الكرنك'],
    ['Philae', 'Philae', 'فيلة'],
    ['Luxor_Temple', 'Luxor Temple', 'معبد الأقصر'],
    ['Bibliotheca_Alexandrina', 'Alexandria Library', 'مكتبة الإسكندرية'],
  ];
  static final Map<String, String> _cache = {};
  bool _done = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    await Future.wait(_items.where((i) => !_cache.containsKey(i[0])).map((i) async {
      try {
        final r = await http.get(Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/${i[0]}'), headers: {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final u = (((jsonDecode(utf8.decode(r.bodyBytes)) as Map)['thumbnail'] as Map?)?['source'] ?? '').toString();
          if (u.isNotEmpty) _cache[i[0]] = u;
        }
      } catch (_) {}
    }));
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _items.where((i) => _cache.containsKey(i[0])).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final i in shown)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlacePage(title: Ui.rtl ? i[2] : i[1], url: 'https://en.wikipedia.org/wiki/${i[0]}'))),
            child: Container(
              width: 76, margin: const EdgeInsetsDirectional.only(end: 8),
              child: Column(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70, width: 2), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                  child: ClipOval(child: Image.network(_cache[i[0]]!, fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                ),
                const SizedBox(height: 3),
                Text(Ui.rtl ? i[2] : i[1], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
              ]),
            ),
          ),
      ]),
    );
  }
}
