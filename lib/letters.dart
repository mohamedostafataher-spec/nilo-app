import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart';
import 'world.dart';
import 'bottles.dart';
import 'screens.dart' show toast;
import 'circles.dart' show niloJoined, niloJoinGate;

/// Place-locked letters. You write a letter for a city. Someone opens it only when their phone is in that city.
/// The phone works out country + city once, on the device, from approximate (coarse) location. Coordinates are never sent or stored.
/// Honest limit: location can be spoofed, so this is a game of presence, not proof.
class LettersPage extends StatefulWidget {
  const LettersPage({super.key});
  @override
  State<LettersPage> createState() => _LettersPageState();
}

class _LettersPageState extends State<LettersPage> {
  bool joined = false, busy = true, locating = false;
  String? hereCc, hereCity;
  int waiting = 0;
  Map? opened;
  List<dynamic> mine = [];
  final body = TextEditingController();
  final city = TextEditingController();
  String cc = Passport.country.isEmpty ? 'EG' : Passport.country;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    joined = await niloJoined();
    if (joined) {
      try { await Sb.signIn(); mine = await Sb.get('letters?select=*&author=eq.${Sb.uid}&order=created_at.desc&limit=20') as List; } catch (_) {}
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) { if (mounted) toast(context, 'Location is off. Allow approximate location to open letters here.'); setState(() => locating = false); return; }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)).timeout(const Duration(seconds: 15));
      final pm = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(const Duration(seconds: 10));
      final f = pm.isNotEmpty ? pm.first : null;
      hereCc = f?.isoCountryCode?.toUpperCase();
      hereCity = (f?.locality?.isNotEmpty ?? false) ? f!.locality : f?.subAdministrativeArea;
      if (hereCc != null && hereCity != null && hereCity!.isNotEmpty) {
        await Sb.signIn();
        waiting = ((await Sb.rpc('letters_waiting', {'c': hereCc, 'ct': hereCity})) as num?)?.toInt() ?? 0;
      } else if (mounted) { toast(context, 'Could not tell the city from this location.'); }
    } catch (_) { if (mounted) toast(context, 'Could not get a location. Try again outside.'); }
    if (mounted) setState(() => locating = false);
  }

  Future<void> _open() async {
    try {
      final r = await Sb.rpc('open_letter', {'c': hereCc, 'ct': hereCity});
      if (r == null) { if (mounted) toast(context, 'No letters waiting here right now.'); } else { opened = Map<String, dynamic>.from(r as Map); Passport.addReeds(5); }
      await _locate();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  Future<void> _write() async {
    final t = body.text.trim(), ct = city.text.trim();
    if (t.length < 3 || ct.length < 2) { toast(context, 'Write the letter and the city.'); return; }
    try {
      await Sb.post('letters', {'author': Sb.uid, 'cc': cc, 'city': ct, 'body': t});
      body.clear(); city.clear();
      if (mounted) toast(context, 'Letter left in $ct. It waits for the first traveler who opens it there.');
      _init();
    } catch (e) {
      if (mounted) toast(context, e.toString().contains('limit') ? 'Daily limit reached (5 letters).' : 'Not saved. No links, emails or phone numbers please.');
    }
  }

  Widget _card(List<Widget> k) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2A4F74))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: k),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Place letters • خطابات الأماكن')), backgroundColor: kBg),
      body: !joined
          ? (busy ? const Center(child: CircularProgressIndicator()) : niloJoinGate(context, _init))
          : ListView(padding: const EdgeInsets.all(14), children: [
              _card([
                Text(L('Open a letter here • افتح خطاب هنا'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(L('Letters can only be opened in the city they were left in. Your phone checks the city once, from approximate location. Coordinates are never saved or sent.'), style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
                const SizedBox(height: 10),
                if (hereCity != null) Text(Ui.rtl ? 'إنت في: $hereCity ($hereCc). خطابات مستنية: $waiting' : 'You are in: $hereCity ($hereCc). Letters waiting: $waiting', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  FilledButton.tonal(onPressed: locating ? null : _locate, child: Text(locating ? 'Checking...' : 'Check my city • اعرف مدينتي')),
                  const SizedBox(width: 8),
                  if (waiting > 0) FilledButton(onPressed: _open, child: Text(L('Open one • افتح'))),
                ]),
                if (opened != null) ...[
                  const Divider(height: 24),
                  Text(L('📜 A letter from another traveler'), style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text((opened!['body'] ?? '').toString(), style: const TextStyle(fontSize: 17, height: 1.5)),
                  const SizedBox(height: 4),
                  Text(L('+5 Reeds'), style: TextStyle(color: kGreen, fontSize: 12)),
                ],
              ]),
              _card([
                Text(L('Leave a letter • سيب خطاب'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                Row(children: [
                  GestureDetector(
                    onTap: () async {
                      final code = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E2A45), isScrollControlled: true, builder: (_) => SafeArea(child: SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: ListView(children: [for (final w in kWorld) ListTile(leading: Text(w[3] as String, style: const TextStyle(fontSize: 26)), title: Text(L('${w[1]} • ${w[2]}')), onTap: () => Navigator.pop(context, w[0] as String))]))));
                      if (code != null) setState(() => cc = code);
                    },
                    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: Text('${countryOf(cc)[3]} $cc ▾')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: city, maxLength: 40, decoration: InputDecoration(counterText: '', hintText: L('City name (as written on a map)')))),
                ]),
                const SizedBox(height: 6),
                TextField(controller: body, maxLength: 400, maxLines: 4, minLines: 3, decoration: InputDecoration(hintText: L('Write something kind for whoever opens it...'))),
                const SizedBox(height: 6),
                FilledButton(onPressed: _write, child: Text(L('Leave it there • سيبه'))),
                Text(L('The city name must match the name your phone gives there (for example Cairo, Paris, Tokyo). 18+, no links or phone numbers.'), style: TextStyle(fontSize: 11, color: Colors.white54)),
              ]),
              if (mine.isNotEmpty)
                _card([
                  Text(L('Your letters • خطاباتك'), style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final m in mine) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${(m as Map)['city']}: ${m['opened_by'] != null ? 'opened by a traveler ✓' : 'waiting'}')),
                ]),
            ]),
    );
  }
}
