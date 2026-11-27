import 'i18n.dart';
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

class _PlacePageState extends State<PlacePage> {
  bool busy = true;
  String text = '', img = '', err = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final t = Uri.parse(widget.url).pathSegments.last;
      final r = await http.get(Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/$t'), headers: {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'}).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      text = (j['extract'] ?? '').toString();
      img = ((j['thumbnail'] as Map?)?['source'] ?? '').toString();
      if (mounted) setState(() => busy = false);
    } catch (_) {
      if (mounted) setState(() { busy = false; err = L('Could not load. Check your connection.'); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (img.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                const SizedBox(height: 12),
                if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.orangeAccent)),
                if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 16, height: 1.6)),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: () => openUrl(widget.url), icon: const Icon(Icons.open_in_new), label: Text(L('Read the full article on Wikipedia'))),
                const SizedBox(height: 14),
                Text(L('Text: Wikipedia (CC BY-SA 4.0), in English. Image: Wikimedia Commons; the author and licence are on the article page.'), style: const TextStyle(fontSize: 11, color: Colors.white38, height: 1.5)),
              ]),
      );
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
