import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'i18n.dart';
import 'main.dart';
import 'vr.dart';

/// "Let's go out": pick one of the real places, send it to a friend as an invite card,
/// and both open the same place in a private room (same room name, so you see each other).
class OutingPicker extends StatefulWidget {
  const OutingPicker({super.key});
  @override
  State<OutingPicker> createState() => _OutingPickerState();
}

class _OutingPickerState extends State<OutingPicker> {
  List places = [];
  bool busy = true;
  String err = '', q = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('https://mohamedostafataher-spec.github.io/nilo-dl/packs/index.json')).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) { places = jsonDecode(utf8.decode(r.bodyBytes)) as List; places.sort((a, b) => a[3].toString().compareTo(b[3].toString())); }
      else { err = L('Could not load places. Try again.'); }
    } catch (_) { err = L('Could not load places. Check your connection.'); }
    if (mounted) setState(() => busy = false);
  }

  static const _names = {'FR': 'France', 'IT': 'Italy', 'GB': 'United Kingdom'};

  @override
  Widget build(BuildContext context) {
    final list = places.where((p) => q.isEmpty || p[3].toString().toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Pick a place • اختار مكان')), backgroundColor: kBg),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: L('Search a place'), border: const OutlineInputBorder()))),
        if (busy) const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(err)),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) {
          final p = list[i];
          final cc = p.length > 4 ? p[4].toString() : 'FR';
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(p[3].toString()),
            subtitle: Text(_names[cc] ?? cc),
            onTap: () => Navigator.pop(context, {'n': p[3].toString(), 'lat': (p[1] as num).toDouble(), 'lon': (p[2] as num).toDouble()}),
          );
        })),
      ]),
    );
  }
}

String newRoomCode() {
  const a = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = math.Random.secure();
  return List.generate(6, (_) => a[r.nextInt(a.length)]).join();
}

const _tag = '🚶GO|';

/// Text form of an invite for chats that only carry text (papyrus replies, group chats).
String outingText(Map pick, String room) => '$_tag$room|${(pick['lat'] as double).toStringAsFixed(3)}|${(pick['lon'] as double).toStringAsFixed(3)}|${pick['n']}';

/// Reads an invite from JSON (friend chat) or from the text form. Returns null if it is not a valid invite.
Map? parseOuting(String b) {
  try {
    if (b.startsWith(_tag)) {
      final p = b.substring(_tag.length).split('|');
      if (p.length < 4) return null;
      final lat = double.parse(p[1]), lon = double.parse(p[2]);
      final n = p.sublist(3).join('|');
      if (!RegExp(r'^[a-z0-9]{4,12}$').hasMatch(p[0]) || lat.abs() > 90 || lon.abs() > 180 || n.isEmpty || n.length > 60) return null;
      return {'n': n, 'lat': lat, 'lon': lon, 'room': p[0]};
    }
    final d = jsonDecode(b);
    return d is Map && d['room'] != null && d['lat'] is num && d['lon'] is num ? d : null;
  } catch (_) { return null; }
}

/// The invite card shown inside the chat.
class OutingCard extends StatelessWidget {
  final String body;
  final bool mine;
  const OutingCard({super.key, required this.body, required this.mine});

  Map? get data => parseOuting(body);

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return Text(L('Outing invite'));
    final name = (d['n'] ?? '').toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions_walk, size: 18, color: kGreen), const SizedBox(width: 6), Text(L('Let\'s go out • يلا نخرج'), style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 6),
      Text(name, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VrPage(scene: 'osm', title: name, lat: (d['lat'] as num).toDouble(), lon: (d['lon'] as num).toDouble(), room: (d['room'] ?? '').toString()))),
        icon: const Icon(Icons.login, size: 18),
        label: Text(mine ? L('Go there') : L('Join')),
      ),
      const SizedBox(height: 4),
      Text(L('You see each other if you both open it with "meet others" on.'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
    ]);
  }
}
