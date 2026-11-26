import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'world.dart' show Passport;

/// Short UI sounds synthesized on the device (no asset files, no downloads).
class Sfx {
  static final Map<String, Uint8List> _cache = {};
  static final AudioPlayer _p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static bool _ctx = false;

  static Uint8List _tone(List<double> freqs, double secs, {double vol = 0.5}) {
    const sr = 22050;
    final n = (sr * secs).floor();
    final seg = n ~/ freqs.length;
    final b = BytesBuilder();
    final h = ByteData(44);
    void s(int o, String t) { for (var i = 0; i < 4; i++) { h.setUint8(o + i, t.codeUnitAt(i)); } }
    s(0, 'RIFF'); h.setUint32(4, 36 + n * 2, Endian.little); s(8, 'WAVE'); s(12, 'fmt ');
    h.setUint32(16, 16, Endian.little); h.setUint16(20, 1, Endian.little); h.setUint16(22, 1, Endian.little);
    h.setUint32(24, sr, Endian.little); h.setUint32(28, sr * 2, Endian.little);
    h.setUint16(32, 2, Endian.little); h.setUint16(34, 16, Endian.little);
    s(36, 'data'); h.setUint32(40, n * 2, Endian.little);
    b.add(h.buffer.asUint8List());
    final d = ByteData(n * 2);
    for (var i = 0; i < n; i++) {
      final f = freqs[math.min(i ~/ seg, freqs.length - 1)];
      final t = i / sr;
      final env = math.min(1.0, i / 200) * math.exp(-3.2 * i / n);
      d.setInt16(i * 2, (math.sin(2 * math.pi * f * t) * env * vol * 32767).round(), Endian.little);
    }
    b.add(d.buffer.asUint8List());
    return b.toBytes();
  }

  static Uint8List _get(String k) => _cache.putIfAbsent(k, () {
    switch (k) {
      case 'send': return _tone([523.25, 783.99, 1046.5], 0.5);
      case 'recv': return _tone([880, 659.25], 0.45);
      case 'tab': return _tone([660], 0.09, vol: 0.3);
      default: return _tone([740], 0.08, vol: 0.3);
    }
  });

  static Future<void> play(String k) async {
    try {
      if (!Passport.flag('sound')) return;
      if (!_ctx) {
        _ctx = true;
        await AudioPlayer.global.setAudioContext(AudioContext(android: const AudioContextAndroid(
          usageType: AndroidUsageType.game, contentType: AndroidContentType.sonification, audioFocus: AndroidAudioFocus.none)));
      }
      await _p.stop();
      await _p.play(BytesSource(_get(k), mimeType: 'audio/wav'), volume: 1.0);
    } catch (_) {}
  }
}
