import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'bottles.dart' show Sb;
import 'health.dart';
import 'i18n.dart';
import 'main.dart';
import 'screens.dart' show toast;
import 'world.dart' show Passport;

/// One greeting and one thank-you per country, in the main local language. Spoken by the phone's own text-to-speech.
class HelloWord {
  final String lang, voice, hello, thanks;
  const HelloWord(this.lang, this.voice, this.hello, this.thanks);
}

const kHello = <String, HelloWord>{
  'FR': HelloWord('French', 'fr-FR', 'Bonjour', 'Merci'),
  'ES': HelloWord('Spanish', 'es-ES', 'Hola', 'Gracias'),
  'MX': HelloWord('Spanish', 'es-MX', 'Hola', 'Gracias'),
  'AR': HelloWord('Spanish', 'es-AR', 'Hola', 'Gracias'),
  'CO': HelloWord('Spanish', 'es-CO', 'Hola', 'Gracias'),
  'IT': HelloWord('Italian', 'it-IT', 'Ciao', 'Grazie'),
  'DE': HelloWord('German', 'de-DE', 'Guten Tag', 'Danke'),
  'AT': HelloWord('German', 'de-DE', 'Guten Tag', 'Danke'),
  'CH': HelloWord('German', 'de-DE', 'Grüezi', 'Danke'),
  'PT': HelloWord('Portuguese', 'pt-PT', 'Olá', 'Obrigado'),
  'BR': HelloWord('Portuguese', 'pt-BR', 'Olá', 'Obrigado'),
  'GB': HelloWord('English', 'en-GB', 'Hello', 'Thank you'),
  'US': HelloWord('English', 'en-US', 'Hello', 'Thank you'),
  'CA': HelloWord('English', 'en-US', 'Hello', 'Thank you'),
  'AU': HelloWord('English', 'en-AU', 'G\'day', 'Thank you'),
  'IE': HelloWord('English', 'en-IE', 'Hello', 'Thank you'),
  'NL': HelloWord('Dutch', 'nl-NL', 'Hallo', 'Dank je'),
  'SE': HelloWord('Swedish', 'sv-SE', 'Hej', 'Tack'),
  'NO': HelloWord('Norwegian', 'nb-NO', 'Hei', 'Takk'),
  'DK': HelloWord('Danish', 'da-DK', 'Hej', 'Tak'),
  'FI': HelloWord('Finnish', 'fi-FI', 'Hei', 'Kiitos'),
  'PL': HelloWord('Polish', 'pl-PL', 'Cześć', 'Dziękuję'),
  'CZ': HelloWord('Czech', 'cs-CZ', 'Ahoj', 'Děkuji'),
  'HU': HelloWord('Hungarian', 'hu-HU', 'Szia', 'Köszönöm'),
  'RO': HelloWord('Romanian', 'ro-RO', 'Salut', 'Mulțumesc'),
  'RU': HelloWord('Russian', 'ru-RU', 'Привет', 'Спасибо'),
  'UA': HelloWord('Ukrainian', 'uk-UA', 'Привіт', 'Дякую'),
  'GR': HelloWord('Greek', 'el-GR', 'Γειά σου', 'Ευχαριστώ'),
  'TR': HelloWord('Turkish', 'tr-TR', 'Merhaba', 'Teşekkürler'),
  'IL': HelloWord('Hebrew', 'he-IL', 'שלום', 'תודה'),
  'EG': HelloWord('Arabic', 'ar-SA', 'أهلا', 'شكرا'),
  'SA': HelloWord('Arabic', 'ar-SA', 'مرحبا', 'شكرا'),
  'AE': HelloWord('Arabic', 'ar-SA', 'مرحبا', 'شكرا'),
  'MA': HelloWord('Arabic', 'ar-SA', 'مرحبا', 'شكرا'),
  'JO': HelloWord('Arabic', 'ar-SA', 'مرحبا', 'شكرا'),
  'IN': HelloWord('Hindi', 'hi-IN', 'नमस्ते', 'धन्यवाद'),
  'PK': HelloWord('Urdu', 'ur-PK', 'السلام علیکم', 'شکریہ'),
  'JP': HelloWord('Japanese', 'ja-JP', 'こんにちは', 'ありがとう'),
  'KR': HelloWord('Korean', 'ko-KR', '안녕하세요', '감사합니다'),
  'CN': HelloWord('Chinese', 'zh-CN', '你好', '谢谢'),
  'TH': HelloWord('Thai', 'th-TH', 'สวัสดี', 'ขอบคุณ'),
  'VN': HelloWord('Vietnamese', 'vi-VN', 'Xin chào', 'Cảm ơn'),
  'ID': HelloWord('Indonesian', 'id-ID', 'Halo', 'Terima kasih'),
  'KE': HelloWord('Swahili', 'sw-KE', 'Habari', 'Asante'),
};

/// Standard (winter) UTC offset in hours for single-zone countries. Summer time is NOT applied, so shown times can be 1 h off. Multi-zone countries are left out.
const kUtc = <String, double>{
  'FR': 1, 'ES': 1, 'IT': 1, 'DE': 1, 'AT': 1, 'CH': 1, 'PT': 0, 'GB': 0, 'IE': 0, 'NL': 1, 'SE': 1, 'NO': 1, 'DK': 1, 'FI': 2, 'PL': 1, 'CZ': 1, 'HU': 1, 'RO': 2,
  'UA': 2, 'GR': 2, 'TR': 3, 'IL': 2, 'EG': 2, 'SA': 3, 'AE': 4, 'MA': 1, 'JO': 3, 'IN': 5.5, 'PK': 5, 'JP': 9, 'KR': 9, 'CN': 8, 'TH': 7, 'VN': 7, 'KE': 3, 'AR': -3, 'CO': -5,
};

/// Card shown on top of a papyrus thread: a word from the other person's country. Collects a stamp the first time it is heard.
class HelloCard extends StatefulWidget {
  final String bid;
  final bool iAmAuthor;
  const HelloCard({super.key, required this.bid, required this.iAmAuthor});
  @override
  State<HelloCard> createState() => _HelloCardState();
}

class _HelloCardState extends State<HelloCard> {
  String cc = '';
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await Sb.rpc('bottle_journey', {'p_id': widget.bid});
      if (r is List && r.isNotEmpty) {
        final f = (r.first['from_cc'] ?? '').toString(), t = (r.first['to_cc'] ?? '').toString();
        final c = widget.iAmAuthor ? t : f;
        if (mounted && c.isNotEmpty && c != Passport.country && kHello.containsKey(c)) setState(() => cc = c);
      }
    } catch (e, st) { Health.log(e, st); }
  }

  /// Local time there (about) and whether the sun is up, from the standard offset.
  String? get _there {
    final o = kUtc[cc];
    if (o == null) return null;
    final t = DateTime.now().toUtc().add(Duration(minutes: (o * 60).round()));
    final h = t.hour + t.minute / 60;
    final day = h >= 6.5 && h < 18.5;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return L('${day ? '☀️ Daytime' : '🌙 Night'} there, about $hm (no summer-time correction) • ${day ? 'عندهم نهار' : 'عندهم ليل'}');
  }

  Future<void> _say(String text, HelloWord w) async {
    try {
      final ok = await _tts.isLanguageAvailable(w.voice);
      if (ok == false) { if (mounted) toast(context, 'No ${w.lang} voice on this phone. Add one in your phone\'s text-to-speech settings.'); return; }
      await _tts.setLanguage(w.voice);
      await _tts.speak(text);
      Passport.addStamp('hello-$cc');
    } catch (e, st) { Health.log(e, st); }
  }

  @override
  Widget build(BuildContext context) {
    final w = kHello[cc];
    if (w == null) return const SizedBox.shrink();
    final flag = String.fromCharCodes(cc.codeUnits.map((u) => 0x1F1E6 + u - 0x41));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(L('A word from their country (${w.lang}) • كلمة من بلدهم'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
          if (_there != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(_there!, style: const TextStyle(fontSize: 12, color: Colors.white70))),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            ActionChip(avatar: const Icon(Icons.volume_up, size: 16), label: Text('${w.hello}  (hello)'), onPressed: () => _say(w.hello, w)),
            ActionChip(avatar: const Icon(Icons.volume_up, size: 16), label: Text('${w.thanks}  (thank you)'), onPressed: () => _say(w.thanks, w)),
          ]),
        ])),
      ]),
    );
  }
}
