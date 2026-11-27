import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'i18n.dart';
import 'main.dart';

/// Landmarks that have an own 3D scene. Key = Wikipedia article name.
const kVrScenes = <String, String>{
  'Giza_pyramid_complex': 'giza', 'Karnak': 'karnak', 'Abu_Simbel_temples': 'abusimbel', 'Abu_Simbel': 'abusimbel',
  'Eiffel_Tower': 'eiffel', 'Leaning_Tower_of_Pisa': 'pisa', 'Big_Ben': 'bigben', 'Elizabeth_Tower': 'bigben', 'Taj_Mahal': 'taj',
  'Hagia_Sophia': 'hagia', 'Colosseum': 'colosseum', 'Statue_of_Liberty': 'liberty', 'Christ_the_Redeemer_(statue)': 'christ',
  'Great_Wall_of_China': 'greatwall', 'Petra': 'petra', 'Sydney_Opera_House': 'opera', 'Mount_Fuji': 'fuji', 'Burj_Khalifa': 'burj', 'Chichen_Itza': 'steppyr',
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
  const VrPage({super.key, required this.scene, required this.title, this.biome = 'green', this.color = 'd8c9a8'});
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
    wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('NiloPhoto', onMessageReceived: (m) => _photo(m.message));
    _load();
  }

  Future<void> _load() async {
    try {
      var html = await rootBundle.loadString('assets/vr/scene.html');
      final three = await rootBundle.loadString('assets/vr/three.min.js');
      final lang = Ui.rtl ? 'ar' : 'en';
      html = html.replaceFirst('<script src="three.min.js"></script>', '<script>$three</script>');
      html = html.replaceFirst('new URLSearchParams(location.search)', "new URLSearchParams('s=${widget.scene}&lang=$lang&b=${widget.biome}&k=${widget.color}&n=${Uri.encodeQueryComponent(widget.title)}')");
      await wc.loadHtmlString(html);
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) setState(() => err = 'Could not start the 3D scene on this phone.');
    }
  }

  Future<void> _photo(String dataUrl) async {
    try {
      final b = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/nilo_visit_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await f.writeAsBytes(b);
      await Share.shareXFiles([XFile(f.path)], text: '${widget.title} • Nilo (3D)');
    } catch (_) {}
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
          SafeArea(child: Align(alignment: AlignmentDirectional.topStart, child: Padding(
            padding: const EdgeInsets.only(top: 34, left: 6, right: 6),
            child: IconButton(style: IconButton.styleFrom(backgroundColor: Colors.black45), onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
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
