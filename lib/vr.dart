import 'health.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:shared_preferences/shared_preferences.dart';
import 'bottles.dart' show Sb;
import 'circles.dart' show niloJoined;
import 'world.dart' show Passport;
import 'screens.dart' show toast;
import 'i18n.dart';
import 'main.dart';

/// Landmarks that have an own 3D scene. Key = Wikipedia article name.
const kVrScenes = <String, String>{
  'Giza_pyramid_complex': 'giza', 'Cairo_Tower': 'cairo', 'Citadel_of_Saladin': 'citadel', 'Cairo_Citadel': 'citadel', 'Mosque_of_Muhammad_Ali': 'citadel', 'Citadel_of_Qaitbay': 'qaitbay', 'Qaitbay_Citadel': 'qaitbay', 'Bibliotheca_Alexandrina': 'library', 'Library_of_Alexandria': 'library', 'Karnak': 'karnak', 'Philae': 'philae', 'Luxor_Temple': 'luxor', 'Abu_Simbel_temples': 'abusimbel', 'Abu_Simbel': 'abusimbel',
  'Eiffel_Tower': 'eiffel', 'Leaning_Tower_of_Pisa': 'pisa', 'Big_Ben': 'bigben', 'Elizabeth_Tower': 'bigben', 'Taj_Mahal': 'taj',
  'Hagia_Sophia': 'hagia', 'Colosseum': 'colosseum', 'Statue_of_Liberty': 'liberty', 'Christ_the_Redeemer_(statue)': 'christ',
  'Great_Wall_of_China': 'greatwall', 'Petra': 'petra', 'Sydney_Opera_House': 'opera', 'Mount_Fuji': 'fuji', 'Burj_Khalifa': 'burj', 'Chichen_Itza': 'steppyr',
  'Blue_Mosque': 'bluemosque', 'Sultan_Ahmed_Mosque': 'bluemosque', 'Cappadocia': 'cappadocia', 'Göreme_National_Park_and_the_Rock_Sites_of_Cappadocia': 'cappadocia', 'Goreme_National_Park': 'cappadocia', 'Pamukkale': 'pamukkale', 'Hierapolis': 'pamukkale', 'Gyeongbokgung': 'gyeong', 'Bulguksa': 'bulguksa',
};

/// Picks a generated scene from the Wikidata type words and the place name. Same type = same shape (honest limit).
String vrTemplate(String types, String name, String cc) {
  final t = '${types.toLowerCase()} ${name.toLowerCase()}';
  bool h(List<String> k) => k.any(t.contains);
  const asia = ['JP', 'CN', 'KR', 'TH', 'VN', 'KH', 'MM', 'LA', 'TW', 'MN', 'NP', 'BT', 'LK'];
  if (h(['pyramid'])) return 'steppyr';
  if (h(['castle', 'fortress', 'fort ', 'palace', 'citadel', 'kremlin', 'chateau'])) return 'castle';
  if (h(['mosque', 'minaret', 'mausoleum', 'tomb'])) return 'dome';
  if (h(['cathedral', 'church', 'basilica', 'monastery', 'abbey', 'cathedr', 'chapel', 'convent'])) return 'cathedral';
  if (h(['pagoda', 'shrine'])) return 'pagoda';
  if (h(['temple']) && asia.contains(cc)) return 'pagoda';
  if (h(['temple', 'sanctuary', 'hypostyle'])) return 'karnak';
  if (h(['tower', 'bridge', 'lighthouse'])) return 'tower';
  if (h(['wall', 'limes'])) return 'wall';
  if (h(['amphitheatre', 'amphitheater', 'theatre', 'arena', 'stadium'])) return 'colosseum';
  if (h(['statue', 'monument', 'memorial'])) return 'statue';
  if (h(['rock-cut', 'rock cut', 'cave', 'canyon'])) return 'petra';
  if (h(['national park', 'nature', 'reserve', 'forest', 'lake', 'island', 'reef', 'volcano', 'mountain', 'valley', 'fjord', 'glacier', 'falls', 'desert', 'wadi', 'bay', 'coast', 'gorge', 'park'])) return 'nature';
  return 'ruins';
}

String vrBiome(String cc, String t) {
  const desert = ['EG', 'SA', 'AE', 'JO', 'IQ', 'LY', 'DZ', 'MA', 'TN', 'OM', 'QA', 'KW', 'YE', 'SD', 'IR', 'SY', 'LB', 'IL', 'PS', 'MR', 'NE', 'TD', 'ML', 'UZ', 'TM', 'BH', 'AF', 'PK'];
  const snow = ['IS', 'NO', 'FI', 'SE', 'GL', 'AQ', 'SJ'];
  const trop = ['BR', 'ID', 'TH', 'VN', 'PH', 'MY', 'LK', 'KE', 'TZ', 'UG', 'CO', 'PE', 'EC', 'VE', 'MX', 'GT', 'BZ', 'HN', 'CR', 'PA', 'CU', 'DO', 'JM', 'KH', 'LA', 'MM', 'IN', 'BD', 'NG', 'GH', 'CM', 'CD', 'MG', 'FJ', 'PG', 'SG', 'BN', 'TL', 'ET'];
  if (t.toLowerCase().contains('glacier') || snow.contains(cc)) return 'snow';
  if (desert.contains(cc)) return 'desert';
  if (trop.contains(cc)) return 'tropical';
  return 'green';
}

/// Wall colour from the country code so each country gets its own palette.
String vrColor(String cc) {
  const pal = ['d8c9a8', 'e9dcc3', 'c9a27a', 'b8a58c', 'e7c9a0', 'c98b6a', 'bfb7a6', 'd9b873'];
  var h = 0;
  for (final c in cc.codeUnits) { h = (h * 31 + c) & 0xffff; }
  return pal[h % pal.length];
}

/// Stylized 3D walk-around scene drawn in code (three.js, MIT licence, bundled in the app, runs offline).
/// It is NOT real photography and not a scan of the real place. Layout and sizes are approximate.
class VrPage extends StatefulWidget {
  final String scene, title, biome, color;
  final double? lat, lon;
  const VrPage({super.key, required this.scene, required this.title, this.biome = 'green', this.color = 'd8c9a8', this.lat, this.lon});
  @override
  State<VrPage> createState() => _VrPageState();
}

class _VrPageState extends State<VrPage> {
  late final WebViewController wc;
  bool ready = false;
  String err = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    wc = WebViewController(onPermissionRequest: (r) => r.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('NiloPhoto', onMessageReceived: (m) => _photo(m.message))
      ..addJavaScriptChannel('NiloReport', onMessageReceived: (m) => _report(m.message))
      ..addJavaScriptChannel('NiloMic', onMessageReceived: (m) => _mic())
      ..addJavaScriptChannel('NiloAvatar', onMessageReceived: (m) async { try { (await SharedPreferences.getInstance()).setString('vr_avatar', m.message); } catch (e, st) { Health.log(e, st); } });
    _load();
  }

  Future<void> _load() async {
    try {
      var html = await rootBundle.loadString('assets/vr/scene.html');
      final three = await rootBundle.loadString('assets/vr/three.min.js');
      final lang = Ui.rtl ? 'ar' : 'en';
      final sp = await SharedPreferences.getInstance();
      var av = sp.getString('vr_avatar') ?? '{}';
      final gnd = sp.getString('p_gender') ?? '';
      if (gnd.isNotEmpty) { try { final m = Map<String, dynamic>.from(jsonDecode(av) as Map); m['bd'] = gnd == 'f' ? 1 : 0; if (gnd != 'f') m['hj'] = 0; av = jsonEncode(m); } catch (e, st) { Health.log(e, st); } }
      final facePath = sp.getString('p_avatar_path') ?? '';
      final mp = await _mpConfig(sp, facePath);
      final texd = <String, String>{};
      for (final k in ['sand', 'grass', 'stone', 'stoneg', 'rock', 'abu1', 'psand', 'psandN', 'pstone', 'pstoneN', 'wS', 'wSN', 'wW', 'wWN', 'fM', 'fMN', 'rK', 'rKN', 'wK', 'wKN', 'rC', 'rCN', 'tr', 'trN', 'sF', 'sFN']) {
        try { texd[k] = 'data:image/jpeg;base64,${base64Encode((await rootBundle.load('assets/vr/tex/$k.jpg')).buffer.asUint8List())}'; } catch (e, st) { Health.log(e, st); }
      }
      final modd = <String, String>{};
      for (final k in ['ram']) {
        try { modd[k] = base64Encode((await rootBundle.load('assets/vr/models/$k.bin')).buffer.asUint8List()); } catch (e, st) { Health.log(e, st); }
      }
      String humd = 'null';
      try { humd = await rootBundle.loadString('assets/vr/human.json'); } catch (e, st) { Health.log(e, st); }
      String humf = 'null';
      try { humf = await rootBundle.loadString('assets/vr/human_f.json'); } catch (e, st) { Health.log(e, st); }
      final gald = <Map<String, String>>[];
      try {
        final gj = jsonDecode(await rootBundle.loadString('assets/vr/gallery.json')) as Map;
        for (final g in (gj[widget.scene] as List? ?? [])) {
          final m = g as Map;
          final d = base64Encode((await rootBundle.load('assets/vr/gal/${m['f']}.jpg')).buffer.asUint8List());
          gald.add({'d': 'data:image/jpeg;base64,$d', 'en': '${m['en']}', 'ar': '${m['ar']}', 'by': '${m['by']}', 'lic': '${m['lic']}'});
        }
      } catch (e, st) { Health.log(e, st); }
      html = html.replaceFirst('<script src="three.min.js"></script>', '<script>window.TEXD=${jsonEncode(texd)};window.MODD=${jsonEncode(modd)};window.GALD=${jsonEncode(gald)};window.GAL_ON=false;window.GLOCK=${gnd.isNotEmpty ? 1 : 0};window.HUMD=$humd;window.HUMDF=$humf</script><script>$three</script>');
      html = html.replaceFirst('new URLSearchParams(location.search)', "new URLSearchParams('s=${widget.scene}&lang=$lang&b=${widget.biome}&k=${widget.color}&n=${Uri.encodeQueryComponent(widget.title)}&av=${Uri.encodeQueryComponent(av)}&mp=${Uri.encodeQueryComponent(mp)}')");
      await wc.loadHtmlString(html, baseUrl: 'https://nilo-dl.vercel.app/');
      _face(facePath);
      if (widget.scene == 'osm' && widget.lat != null) _osm();
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => err = 'Could not start the 3D scene on this phone.');
    }
  }

  String osmStatus = '';

  /// Real map data around the place from OpenStreetMap (Overpass API). Cached on the phone for 7 days.
  Future<void> _osm() async {
    final lat = widget.lat!, lon = widget.lon!;
    try {
      if (mounted) setState(() => osmStatus = L('Loading real streets and buildings... • بنحمّل الشوارع والمباني الحقيقية...'));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/osm_${lat.toStringAsFixed(3)}_${lon.toStringAsFixed(3)}.json');
      String json = '';
      if (await f.exists() && DateTime.now().difference(await f.lastModified()).inDays < 7) json = await f.readAsString();
      if (json.isEmpty) {
        final q = '[out:json][timeout:40][maxsize:20000000];(way["building"](around:350,$lat,$lon);way["highway"](around:350,$lat,$lon);way["natural"="water"](around:350,$lat,$lon);way["leisure"~"^(park|garden)\$"](around:350,$lat,$lon););out geom tags 5000;';
        dynamic data;
        for (final host in ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter']) {
          try {
            final r = await http.post(Uri.parse(host), headers: {'User-Agent': 'Nilo/1.5 (tourist app)'}, body: {'data': q}).timeout(const Duration(seconds: 50));
            if (r.statusCode == 200) { data = jsonDecode(utf8.decode(r.bodyBytes)); break; }
          } catch (e, st) { Health.log(e, st); }
        }
        if (data == null) { if (mounted) setState(() => osmStatus = L('Map server is busy. Try again in a minute. • سيرفر الخريطة مشغول. جرب بعد دقيقة.')); return; }
        json = jsonEncode(_osmCompact(data['elements'] as List, lat, lon));
        await f.writeAsString(json);
      }
      await wc.runJavaScript('window.nilo_loadOsm($json)');
      if (mounted) setState(() => osmStatus = '');
    } catch (_) {
      if (mounted) setState(() => osmStatus = L('Could not load the map data. • مقدرناش نحمّل بيانات الخريطة.'));
    }
  }

  Map<String, dynamic> _osmCompact(List els, double lat0, double lon0) {
    final kx = 111320 * math.cos(lat0 * math.pi / 180), kz = 110540;
    List<List<double>> pr(List g) => [for (final p in g) [double.parse(((p['lon'] - lon0) * kx).toStringAsFixed(1)), double.parse((-(p['lat'] - lat0) * kz).toStringAsFixed(1))]];
    const w = {'motorway': 12, 'trunk': 11, 'primary': 10, 'secondary': 8, 'tertiary': 7, 'residential': 6, 'unclassified': 6, 'service': 4, 'pedestrian': 5, 'footway': 2.5, 'path': 2, 'cycleway': 2.5, 'steps': 2};
    final b = <Map>[], r = <Map>[], wa = <List>[], g = <List>[];
    for (final e in els) {
      final t = (e['tags'] ?? {}) as Map, geo = e['geometry'] as List?;
      if (geo == null || geo.length < 2) continue;
      final closed = geo.length >= 4 && geo.first['lat'] == geo.last['lat'] && geo.first['lon'] == geo.last['lon'];
      final poly = closed ? geo.sublist(0, geo.length - 1) : geo;
      if (t.containsKey('building') && closed) {
        double? h = double.tryParse(RegExp(r'[0-9.]+').stringMatch((t['height'] ?? '').toString()) ?? '');
        h ??= (double.tryParse((t['building:levels'] ?? '').toString()) ?? 2.8) * 3.2;
        if (h < 3) h = 3;
        if (h > 300) h = 300;
        b.add({'h': h, 'p': pr(poly)});
      } else if (t.containsKey('highway')) {
        r.add({'w': (w[t['highway']] ?? 4), 'p': pr(geo)});
      } else if (t['natural'] == 'water' && closed) {
        wa.add(pr(poly));
      } else if ((t['leisure'] == 'park' || t['leisure'] == 'garden') && closed) {
        g.add(pr(poly));
      }
    }
    return {'b': b.take(1800).toList(), 'r': r.take(1500).toList(), 'w': wa, 'g': g};
  }

  static final _uuid = RegExp(r'^[0-9a-fA-F-]{36}$');

  /// Online presence config. Empty (solo) unless the user joined (18+), is signed in, and switched "meet others" on.
  Future<String> _mpConfig(SharedPreferences sp, String facePath) async {
    try {
      if (!await niloJoined()) return '';
      if (sp.getBool('vr_online') == null && mounted) {
        final ok = await _consent();
        await sp.setBool('vr_online', ok);
      }
      if (sp.getBool('vr_online') != true) return '';
      if (Sb.uid == null) await Sb.signIn();
      if (Sb.uid == null) return '';
      var blocked = <String>[];
      try {
        final r = await Sb.get('blocks?blocker=eq.${Sb.uid}&select=blocked');
        blocked = [for (final x in (r as List)) x['blocked'].toString()];
      } catch (e, st) { Health.log(e, st); }
      final share = (sp.getBool('vr_face') ?? false) && facePath.isNotEmpty;
      return jsonEncode({
        'url': Sb.baseUrl, 'key': Sb.anonKey, 'uid': Sb.uid, 'nick': sp.getString('b_nick') ?? '', 'cc': Passport.country,
        'room': () {
          final pc = (sp.getString('vr_room') ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final base = widget.scene == 'osm' ? 'osm-${widget.lat!.toStringAsFixed(3)}_${widget.lon!.toStringAsFixed(3)}' : widget.scene;
          return pc.length >= 4 ? 'pr$pc-$base' : (widget.scene == 'osm' ? base : '');
        }(),
        'face': share ? Sb.publicUrl(facePath) : '', 'fp': Sb.publicUrl(''), 'blocked': blocked,
      });
    } catch (_) { return ''; }
  }

  Future<bool> _consent() async {
    bool face = false;
    final r = await showDialog<bool>(context: context, barrierDismissible: false, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: Text(L('Meet other travellers here? • قابل مسافرين هنا؟')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('Other adults (18+) in the same place see your avatar, nickname, country flag and what you type in the chat bubble. No location, nothing is saved. Voice is optional, off by default, and not moderated. Up to 6 people per room. Tap a name to report or block. Meet only in public places; never share contact details.'), style: const TextStyle(fontSize: 13, height: 1.4)),
        const SizedBox(height: 8),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: face, onChanged: (v) => setS(() => face = v), title: Text(L('Show my profile photo as my avatar face'), style: const TextStyle(fontSize: 13))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Stay solo'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(L('Meet others'))),
      ],
    )));
    (await SharedPreferences.getInstance()).setBool('vr_face', face && r == true);
    return r == true;
  }

  Future<void> _settings() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    bool on = sp.getBool('vr_online') ?? false, face = sp.getBool('vr_face') ?? false;
    final rc = TextEditingController(text: sp.getString('vr_room') ?? '');
    await showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: Text(L('Meeting others • مقابلة الناس')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, value: on, onChanged: (v) { setS(() => on = v); sp.setBool('vr_online', v); }, title: Text(L('Meet other travellers here • قابل مسافرين هنا'), style: const TextStyle(fontSize: 13))),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: face, onChanged: (v) { setS(() => face = v); sp.setBool('vr_face', v); }, title: Text(L('Show my profile photo as my avatar face'), style: const TextStyle(fontSize: 13))),
        TextField(controller: rc, maxLength: 12, onChanged: (v) => sp.setString('vr_room', v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')), decoration: InputDecoration(labelText: L('Private room code (friends only) • كود غرفة خاصة'), helperText: L('Empty = public. Only people with the same code in the same place meet you. • فاضي = عام'), helperMaxLines: 2)),
        Row(children: [
          TextButton(onPressed: () { const a = 'abcdefghjkmnpqrstuvwxyz23456789'; final r = math.Random.secure(); final c2 = List.generate(6, (_) => a[r.nextInt(a.length)]).join(); rc.text = c2; sp.setString('vr_room', c2); setS(() {}); }, child: Text(L('New code • كود جديد'))),
          TextButton(onPressed: () { final c2 = rc.text.trim(); if (c2.length < 4) return; Share.share('Join me in a private room on Nilo. Open the 3D place, tap the groups icon and enter code: $c2\nhttps://mohamedostafataher-spec.github.io/nilo-dl'); }, child: Text(L('Share invite • ابعت دعوة'))),
        ]),
        Text(L('Changes apply the next time you open a place. • التغييرات بتتطبق لما تفتح مكان تاني.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(L('OK')))],
    )));
  }

  Future<void> _mic() async {
    bool ok = false;
    try { final rec = AudioRecorder(); ok = await rec.hasPermission(); await rec.dispose(); } catch (e, st) { Health.log(e, st); }
    try { await wc.runJavaScript('window.nilo_micOk($ok)'); } catch (e, st) { Health.log(e, st); }
  }

  Future<void> _report(String msg) async {
    try {
      final m = jsonDecode(msg) as Map;
      final u = (m['u'] ?? '').toString();
      if (!_uuid.hasMatch(u)) return;
      if (m['a'] == 'block') {
        await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': u}, upsert: true);
        if (mounted) toast(context, L('Blocked.'));
      } else {
        await Sb.rpc('report_place_user', {'p_user': u, 'p_place': (m['p'] ?? '').toString()});
        if (mounted) toast(context, L('Reported. Thank you.'));
      }
    } catch (e, st) { Health.log(e, st); }
  }

  /// Own profile photo as the avatar's face. Loaded from the user's own photo, shown only on this phone here.
  Future<void> _face(String path) async {
    if (path.isEmpty) return;
    try {
      final c = HttpClient();
      final rq = await c.getUrl(Uri.parse(Sb.publicUrl(path))).timeout(const Duration(seconds: 10));
      final rs = await rq.close().timeout(const Duration(seconds: 10));
      if (rs.statusCode != 200) return;
      final b = await consolidateHttpClientResponseBytes(rs);
      if (b.length > 3000000) return;
      await Future.delayed(const Duration(milliseconds: 800));
      await wc.runJavaScript("window.nilo_setFace('data:image/jpeg;base64,${base64Encode(b)}')");
    } catch (e, st) { Health.log(e, st); }
  }

  Future<void> _photo(String dataUrl) async {
    try {
      final b = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/nilo_visit_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(b);
      await Share.shareXFiles([XFile(f.path)], text: '${widget.title} • Nilo (3D)');
    } catch (e, st) { Health.log(e, st); }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          if (ready) Positioned.fill(child: WebViewWidget(controller: wc)),
          if (!ready && err.isEmpty) const Center(child: CircularProgressIndicator()),
          if (err.isNotEmpty) Center(child: Text(err, style: const TextStyle(color: Colors.orangeAccent))),
          if (osmStatus.isNotEmpty) Positioned(left: 24, right: 24, bottom: 120, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text(osmStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
          SafeArea(child: Align(alignment: AlignmentDirectional.topStart, child: Padding(
            padding: const EdgeInsets.only(top: 34, left: 6, right: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(style: IconButton.styleFrom(backgroundColor: Colors.black45), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const SizedBox(width: 6),
              IconButton(style: IconButton.styleFrom(backgroundColor: Colors.black45), onPressed: _settings, icon: const Icon(Icons.groups_outlined, color: Colors.white)),
            ]),
          ))),
        ]),
      );
}

/// Hand-tuned landmark scenes by country (Wikipedia title, English name, Arabic name). Grows batch by batch.
const kVrByCountry = <String, List<List<String>>>{
  'EG': [['Giza_pyramid_complex', 'Giza Pyramids', 'أهرامات الجيزة'], ['Karnak', 'Karnak Temple', 'معبد الكرنك'], ['Abu_Simbel_temples', 'Abu Simbel', 'أبو سمبل']],
  'FR': [['Eiffel_Tower', 'Eiffel Tower', 'برج إيفل']],
  'IT': [['Colosseum', 'Colosseum', 'الكولوسيوم'], ['Leaning_Tower_of_Pisa', 'Leaning Tower of Pisa', 'برج بيزا المائل']],
  'GB': [['Big_Ben', 'Big Ben', 'بيج بن']],
  'IN': [['Taj_Mahal', 'Taj Mahal', 'تاج محل']],
  'TR': [['Hagia_Sophia', 'Hagia Sophia', 'آيا صوفيا']],
  'US': [['Statue_of_Liberty', 'Statue of Liberty', 'تمثال الحرية']],
  'BR': [['Christ_the_Redeemer_(statue)', 'Christ the Redeemer', 'المسيح الفادي']],
  'CN': [['Great_Wall_of_China', 'Great Wall of China', 'سور الصين العظيم']],
  'JO': [['Petra', 'Petra', 'البتراء']],
  'AU': [['Sydney_Opera_House', 'Sydney Opera House', 'دار أوبرا سيدني']],
  'JP': [['Mount_Fuji', 'Mount Fuji', 'جبل فوجي']],
  'AE': [['Burj_Khalifa', 'Burj Khalifa', 'برج خليفة']],
  'MX': [['Chichen_Itza', 'Chichen Itza', 'تشيتشن إيتزا']],
};
