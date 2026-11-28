import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'health.dart';
import 'i18n.dart';
import 'world.dart' show Passport;

/// Letter-by-letter spelling of a Latin nickname in other scripts. Sound-alike, NOT a real translation or transliteration standard.
const _hiero = {
  'a': '𓄿', 'b': '𓃀', 'c': '𓎡', 'd': '𓂧', 'e': '𓇋', 'f': '𓆑', 'g': '𓎼', 'h': '𓉔', 'i': '𓇋', 'j': '𓆓', 'k': '𓎡', 'l': '𓃭',
  'm': '𓅓', 'n': '𓈖', 'o': '𓅱', 'p': '𓊪', 'q': '𓈎', 'r': '𓂋', 's': '𓋴', 't': '𓏏', 'u': '𓅱', 'v': '𓆑', 'w': '𓅱', 'x': '𓎡𓋴', 'y': '𓇌', 'z': '𓊃',
};
const _cyr = {
  'a': 'а', 'b': 'б', 'c': 'к', 'd': 'д', 'e': 'е', 'f': 'ф', 'g': 'г', 'h': 'х', 'i': 'и', 'j': 'дж', 'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н', 'o': 'о',
  'p': 'п', 'q': 'к', 'r': 'р', 's': 'с', 't': 'т', 'u': 'у', 'v': 'в', 'w': 'в', 'x': 'кс', 'y': 'й', 'z': 'з',
};
const _grk = {
  'a': 'α', 'b': 'β', 'c': 'κ', 'd': 'δ', 'e': 'ε', 'f': 'φ', 'g': 'γ', 'h': 'η', 'i': 'ι', 'j': 'τζ', 'k': 'κ', 'l': 'λ', 'm': 'μ', 'n': 'ν', 'o': 'ο',
  'p': 'π', 'q': 'κ', 'r': 'ρ', 's': 'σ', 't': 'τ', 'u': 'υ', 'v': 'β', 'w': 'ου', 'x': 'ξ', 'y': 'υ', 'z': 'ζ',
};
const _ar = {
  'a': 'ا', 'b': 'ب', 'c': 'ك', 'd': 'د', 'e': 'ي', 'f': 'ف', 'g': 'غ', 'h': 'ه', 'i': 'ي', 'j': 'ج', 'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن', 'o': 'و',
  'p': 'ب', 'q': 'ق', 'r': 'ر', 's': 'س', 't': 'ت', 'u': 'و', 'v': 'ف', 'w': 'و', 'x': 'كس', 'y': 'ي', 'z': 'ز',
};

String spell(String nick, Map<String, String> m, {bool rtl = false}) {
  final out = StringBuffer();
  for (final r in nick.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    out.write(m[ch] ?? (RegExp(r'[a-z]').hasMatch(ch) ? '' : (ch == ' ' ? ' ' : '')));
  }
  return out.toString().trim();
}

class NameCardPage extends StatefulWidget {
  const NameCardPage({super.key});
  @override
  State<NameCardPage> createState() => _NameCardPageState();
}

class _NameCardPageState extends State<NameCardPage> {
  final key = GlobalKey();
  late final TextEditingController c = TextEditingController(text: _latin(Passport.nickname));
  static String _latin(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();

  Future<void> _share() async {
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/nilo_name_card.png');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)], text: 'My name on a Nilo papyrus');
    } catch (e, st) { Health.log(e, st); }
  }

  Widget _row(String label, String text, {bool rtl = false, double size = 26}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7A5A1E), letterSpacing: 1)),
      Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: Text(text.isEmpty ? '-' : text, textAlign: TextAlign.center, style: TextStyle(fontSize: size, color: const Color(0xFF3B2A0C), fontWeight: FontWeight.w700))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final n = c.text;
    return Scaffold(
      appBar: AppBar(title: Text(L('Name card • كارت الاسم'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: c, maxLength: 20, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: L('Name in English letters • الاسم بحروف إنجليزي'), border: const OutlineInputBorder())),
        const SizedBox(height: 8),
        RepaintBoundary(
          key: key,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFE8D5A3), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF7A5A1E), width: 3)),
            child: Column(children: [
              const Text('𓂀', style: TextStyle(fontSize: 30, color: Color(0xFF7A5A1E))),
              _row('HIEROGLYPHS (sound-alike)', spell(n, _hiero), size: 34),
              const Divider(color: Color(0xFF7A5A1E)),
              _row('ARABIC', spell(n, _ar), rtl: true),
              _row('CYRILLIC', spell(n, _cyr)),
              _row('GREEK', spell(n, _grk)),
              const Divider(color: Color(0xFF7A5A1E)),
              Text(n.trim().isEmpty ? '' : n.trim(), style: const TextStyle(fontSize: 18, color: Color(0xFF3B2A0C))),
              const SizedBox(height: 6),
              const Text('Nilo • approximate letter-by-letter spelling, not a translation', style: TextStyle(fontSize: 9, color: Color(0xFF7A5A1E))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: n.trim().isEmpty ? null : _share, icon: const Icon(Icons.share), label: Text(L('Share the card • شارك الكارت'))),
        const SizedBox(height: 8),
        Text(L('Honest note: this swaps each letter for a similar sound. Real hieroglyphic or Russian spelling of a name can differ.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
    );
  }
}
