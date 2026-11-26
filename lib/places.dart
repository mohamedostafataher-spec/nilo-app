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
              onTap: it['url']!.isEmpty ? null : () => openUrl(it['url']!),
            ),
          ),
        const SizedBox(height: 12),
        Text(L('Data: Wikidata (CC0). Links: Wikipedia (CC BY-SA).'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ]),
    );
  }
}
