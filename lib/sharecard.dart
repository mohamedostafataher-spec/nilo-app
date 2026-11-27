import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import 'main.dart';
import 'world.dart' show Passport, countryOf;

/// Share card: a picture drawn on the phone (country flag, streak, papyri, countries). It has no name, no ID, no location.
/// It opens the phone share sheet; the user picks where it goes. Nilo posts nothing and sends nothing by itself.
const kNiloLink = 'https://mohamedostafataher-spec.github.io/nilo-dl';

Future<void> showShareCard(BuildContext context) => showDialog(context: context, builder: (_) => const _ShareCardDialog());

class _ShareCardDialog extends StatefulWidget {
  const _ShareCardDialog();
  @override
  State<_ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<_ShareCardDialog> {
  final key = GlobalKey();
  bool busy = false;

  Future<void> _share() async {
    setState(() => busy = true);
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/nilo_card.png');
      await f.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path)], text: '${L('I am sending papyri across the world on Nilo, a translation app for travelers.')} $kNiloLink');
    } catch (_) {}
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Passport.country.isEmpty ? countryOf('EG') : countryOf(Passport.country);
    final n = Passport.stamps.where((x) => x.startsWith('word-') || x.startsWith('home-')).map((x) => x.substring(x.indexOf('-') + 1)).toSet().length;
    return Dialog(
      backgroundColor: kBg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: key,
            child: Container(
              width: 300, padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B1F33), Color(0xFF1C4A6E)]),
                borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE0B04A), width: 2)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('نيلو  Nilo', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFE0B04A))),
                const SizedBox(height: 14),
                Text(c[3] as String, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 6),
                Text('${c[1]} • ${c[2]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Text('🔥 ${Passport.streak}   📜 ${Passport.papyri}   🌍 $n', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 14),
                const Text('Papyri across the world, translated for you\nبرديات حوالين العالم، مترجمة ليك', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5)),
                const SizedBox(height: 10),
                const Text('mohamedostafataher-spec.github.io/nilo-dl', style: TextStyle(fontSize: 12, color: Color(0xFFE0B04A))),
                const SizedBox(height: 4),
                const Text('تطبيق مصري خالص', style: TextStyle(fontSize: 11, color: Colors.white54)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text(L('The card has no name and no location. You choose where to share it.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(L('Close'))),
            FilledButton.icon(onPressed: busy ? null : _share, icon: const Icon(Icons.share), label: Text(L('Share'))),
          ]),
        ]),
      ),
    );
  }
}
