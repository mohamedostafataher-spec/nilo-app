import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'bottles.dart';
import 'health.dart';
import 'i18n.dart';
import 'net.dart' show Mic;
import 'screens.dart' show toast;

/// Photos and voice notes in friend chats. Files live in the private `dm` bucket under the sender's id.
/// The server only lets friends (not blocked, 18+) send, and only the two people can read the file.
class DmMedia {
  static const maxBytes = 2900000;
  static const maxVoiceSeconds = 30;

  static Future<String?> sendBytes(String toUid, String kind, List<int> bytes, String mime, String ext) async {
    if (bytes.length > maxBytes) return 'File is too big.';
    final me = Sb.uid;
    if (me == null) return 'Sign in first.';
    final path = '$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      final r = await http.post(Uri.parse('${Sb.baseUrl}/storage/v1/object/dm/$path'),
          headers: {'apikey': Sb.anonKey, 'Authorization': 'Bearer ${Sb.token}', 'Content-Type': mime}, body: bytes).timeout(const Duration(seconds: 40));
      if (r.statusCode >= 300) return 'Upload failed.';
      final ok = await Sb.rpc('send_dm_media', {'p_uid': toUid, 'p_kind': kind, 'p_path': path});
      if (ok == true) return null;
      await http.delete(Uri.parse('${Sb.baseUrl}/storage/v1/object/dm/$path'), headers: {'apikey': Sb.anonKey, 'Authorization': 'Bearer ${Sb.token}'});
      return 'Could not send. You must be friends, and not blocked.';
    } catch (e, st) {
      Health.log(e, st);
      return 'Could not send. Check your connection and try again.';
    }
  }

  static Future<String?> pickAndSendPhoto(String toUid) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 80);
    if (x == null) return null;
    final b = await x.readAsBytes();
    return sendBytes(toUid, 'photo', b, 'image/jpeg', 'jpg');
  }

  static final _cache = <String, Uint8List>{};
  static Future<Uint8List?> load(String path) async {
    final c = _cache[path];
    if (c != null) return c;
    try {
      final r = await http.get(Uri.parse('${Sb.baseUrl}/storage/v1/object/authenticated/dm/$path'), headers: {'apikey': Sb.anonKey, 'Authorization': 'Bearer ${Sb.token}'}).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      if (_cache.length > 30) _cache.clear();
      return _cache[path] = r.bodyBytes;
    } catch (e, st) {
      Health.log(e, st);
      return null;
    }
  }
}

class DmMediaBubble extends StatefulWidget {
  final String kind, path;
  const DmMediaBubble({super.key, required this.kind, required this.path});
  @override
  State<DmMediaBubble> createState() => _DmMediaBubbleState();
}

class _DmMediaBubbleState extends State<DmMediaBubble> {
  Uint8List? data;
  bool failed = false, playing = false;
  AudioPlayer? _p;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'photo') _fetch();
  }

  Future<void> _fetch() async {
    final b = await DmMedia.load(widget.path);
    if (!mounted) return;
    setState(() { data = b; failed = b == null; });
  }

  @override
  void dispose() { _p?.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    if (playing) { await _p?.stop(); if (mounted) setState(() => playing = false); return; }
    final b = data ?? await DmMedia.load(widget.path);
    if (b == null) { if (mounted) toast(context, 'Could not load the voice note.'); return; }
    data = b;
    _p ??= AudioPlayer();
    _p!.onPlayerComplete.listen((_) { if (mounted) setState(() => playing = false); });
    try {
      await _p!.play(BytesSource(b));
      if (mounted) setState(() => playing = true);
    } catch (e, st) { Health.log(e, st); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == 'voice') {
      return InkWell(
        onTap: _toggle,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 32),
          const SizedBox(width: 8),
          Text(L('Voice note • رسالة صوتية')),
        ]),
      );
    }
    if (failed) return Text(L('Photo unavailable • الصورة مش متاحة'), style: const TextStyle(color: Colors.white60));
    if (data == null) return const SizedBox(width: 60, height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (c) => Dialog(backgroundColor: Colors.black, child: InteractiveViewer(child: Image.memory(data!)))),
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(data!, width: 220, fit: BoxFit.cover, cacheWidth: 660)),
    );
  }
}

/// Mic button: tap to start, tap again to stop and send (max 30 s).
class DmVoiceButton extends StatefulWidget {
  final String toUid;
  final VoidCallback onSent;
  const DmVoiceButton({super.key, required this.toUid, required this.onSent});
  @override
  State<DmVoiceButton> createState() => _DmVoiceButtonState();
}

class _DmVoiceButtonState extends State<DmVoiceButton> {
  final _mic = Mic();
  bool rec = false, busy = false;
  Timer? _cap;

  @override
  void dispose() { _cap?.cancel(); super.dispose(); }

  Future<void> _tap() async {
    if (busy) return;
    if (!rec) {
      final ok = await _mic.start();
      if (!ok) { if (mounted) toast(context, 'Microphone permission is needed.'); return; }
      setState(() => rec = true);
      _cap = Timer(const Duration(seconds: DmMedia.maxVoiceSeconds), () { if (rec) _tap(); });
      return;
    }
    _cap?.cancel();
    setState(() { rec = false; busy = true; });
    final bytes = await _mic.stop();
    String? err;
    if (bytes == null || bytes.length < 1500) { err = 'Too short.'; } else { err = await DmMedia.sendBytes(widget.toUid, 'voice', bytes, 'audio/mp4', 'm4a'); }
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) { toast(context, err); } else { widget.onSent(); }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: L('Voice note • رسالة صوتية'),
        icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(rec ? Icons.stop_circle : Icons.mic, color: rec ? Colors.redAccent : null),
        onPressed: _tap,
      );
}
