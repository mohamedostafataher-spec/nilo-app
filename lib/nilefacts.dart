import 'i18n.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'screens.dart' show openUrl;

/// Real-world Nile cards. Facts come live from Wikidata (CC0) and the Wikipedia summary (CC BY-SA 4.0). Nothing is written by Nilo.
class NileFactsPage extends StatefulWidget {
  const NileFactsPage({super.key});
  @override
  State<NileFactsPage> createState() => _NileFactsPageState();
}

class _NileFactsPageState extends State<NileFactsPage> {
  bool busy = true;
  String err = '', len = '', basin = '', src = '', mouth = '', summary = '', date = '';
  final countries = <String>[];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      const q = 'SELECT ?len ?basin ?cl ?mouthL ?srcL WHERE { wd:Q3392 wdt:P2043 ?len. OPTIONAL{wd:Q3392 wdt:P2053 ?basin} '
          'OPTIONAL{wd:Q3392 wdt:P205 ?c. ?c rdfs:label ?cl FILTER(LANG(?cl)="en")} '
          'OPTIONAL{wd:Q3392 wdt:P403 ?m. ?m rdfs:label ?mouthL FILTER(LANG(?mouthL)="en")} '
          'OPTIONAL{wd:Q3392 wdt:P885 ?s. ?s rdfs:label ?srcL FILTER(LANG(?srcL)="en")} }';
      const ua = {'User-Agent': 'Nilo/1.5 (mohamedostafataher@gmail.com)'};
      final r = await http.get(Uri.https('query.wikidata.org', '/sparql', {'query': q, 'format': 'json'}), headers: {...ua, 'Accept': 'application/sparql-results+json'}).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final rows = jsonDecode(utf8.decode(r.bodyBytes))['results']['bindings'] as List;
      final set = <String>{};
      for (final b in rows) {
        len = b['len']['value'].toString();
        basin = (b['basin']?['value'] ?? '').toString();
        src = (b['srcL']?['value'] ?? '').toString();
        mouth = (b['mouthL']?['value'] ?? '').toString();
        final c = (b['cl']?['value'] ?? '').toString();
        if (c.isNotEmpty) set.add(c);
      }
      countries.addAll(set.toList()..sort());
      try {
        final w = await http.get(Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/Nile'), headers: ua).timeout(const Duration(seconds: 15));
        if (w.statusCode == 200) summary = (jsonDecode(utf8.decode(w.bodyBytes))['extract'] ?? '').toString();
      } catch (_) {}
      final n = DateTime.now().toUtc();
      date = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
      if (mounted) setState(() => busy = false);
    } catch (_) {
      if (mounted) setState(() { busy = false; err = L('Could not load. Check your connection.'); });
    }
  }

  Widget _card(String title, String value, IconData ic) => Card(
        color: const Color(0xFF12304D),
        child: ListTile(leading: Icon(ic, color: kGreen), title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.white60)), subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('The Nile, real facts')), backgroundColor: kBg),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(14), children: [
                if (err.isNotEmpty) Text(err, style: const TextStyle(color: Colors.orangeAccent)),
                if (len.isNotEmpty) _card(L('Length'), '$len km', Icons.straighten),
                if (basin.isNotEmpty) _card(L('Drainage basin'), '$basin km²', Icons.water),
                if (src.isNotEmpty) _card(L('Source'), src, Icons.landscape),
                if (mouth.isNotEmpty) _card(L('Mouth'), mouth, Icons.waves),
                if (countries.isNotEmpty) _card(L('Basin countries listed on Wikidata'), countries.join(', '), Icons.public),
                if (summary.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(summary, style: const TextStyle(height: 1.6, fontSize: 15))),
                OutlinedButton.icon(onPressed: () => openUrl('https://en.wikipedia.org/wiki/Nile'), icon: const Icon(Icons.open_in_new), label: Text(L('Read the full article on Wikipedia'))),
                const SizedBox(height: 10),
                Text('${L('Facts: Wikidata (CC0). Text: Wikipedia (CC BY-SA 4.0), in English. Loaded live on')} $date. ${L('Wikidata may list fewer countries than other sources.')}', style: const TextStyle(fontSize: 11, color: Colors.white38, height: 1.5)),
              ]),
      );
}
