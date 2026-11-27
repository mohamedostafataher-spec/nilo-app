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
const kVrScenes = <String, String>{'Giza_pyramid_complex': 'giza', 'Karnak': 'karnak'};

/// Stylized 3D walk-around scene drawn in code (three.js, MIT licence, bundled in the app, runs offline).
/// It is NOT real photography and not a scan of the real place. Layout and sizes are approximate.
class VrPage extends StatefulWidget {
  final String scene, title;
  const VrPage({super.key, required this.scene, required this.title});
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
      html = html.replaceFirst('new URLSearchParams(location.search)', "new URLSearchParams('s=${widget.scene}&lang=$lang')");
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
