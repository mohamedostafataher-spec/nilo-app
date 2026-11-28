import 'health.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'data.dart';

class TrResult {
  final String original, translation, rom, note, lang, error;
  final bool empty;
  TrResult({this.original = '', this.translation = '', this.rom = '', this.note = '', this.lang = '', this.error = '', this.empty = false});
  bool get ok => translation.isNotEmpty;
}

Future<TrResult> trCall(Map<String, dynamic> body) async {
  for (var i = 0; i < 2; i++) {
    try {
      final r = await http
          .post(Uri.parse('$kSite/api/tr'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final res = TrResult(
        original: (j['original'] ?? '').toString(),
        translation: (j['translation'] ?? '').toString(),
        rom: (j['rom'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
        lang: (j['lang'] ?? '').toString(),
        error: (j['error'] ?? '').toString(),
        empty: j['empty'] == true,
      );
      if (res.ok || res.empty || r.statusCode == 400 || r.statusCode == 413 || r.statusCode == 429) return res;
    } catch (e, st) { Health.log(e, st); }
  }
  return TrResult(error: 'مفيش اتصال أو الخدمة مشغولة. جرب تاني.');
}

Future<TrResult> trText(String text, String from, String to, [String tone = 'natural']) =>
    trCall({'text': text, 'from': from, 'to': to, 'tone': tone});

Future<TrResult> trAudio(List<int> bytes, String mime, String from, String to, [String tone = 'natural']) =>
    trCall({'audio': base64Encode(bytes), 'mime': mime, 'from': from, 'to': to, 'tone': tone});

Future<TrResult> trImage(List<int> bytes, String mime, String to) =>
    trCall({'image': base64Encode(bytes), 'imime': mime, 'from': 'auto', 'to': to, 'tone': 'natural'});

final FlutterTts _tts = FlutterTts();
Future<bool> speak(String text, String lang) async {
  try {
    final loc = kLocale[lang] ?? 'en-US';
    await _tts.stop();
    await _tts.setLanguage(loc);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
    return true;
  } catch (_) {
    return false;
  }
}

class Mic {
  final AudioRecorder _r = AudioRecorder();
  String? _path;
  Future<bool> start() async {
    if (!await _r.hasPermission()) return false;
    final d = await getTemporaryDirectory();
    _path = '${d.path}/nilo_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _r.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 32000), path: _path!);
    return true;
  }

  Future<List<int>?> stop() async {
    final p = await _r.stop();
    if (p == null) return null;
    final f = File(p);
    if (!await f.exists()) return null;
    final b = await f.readAsBytes();
    await f.delete();
    return b;
  }

  Future<void> dispose() => _r.dispose();
}
