import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data.dart';
import 'main.dart';
import 'net.dart';
import 'screens.dart';

/// Live translated talk between two phones.
/// Turn-based: one person speaks, the other hears the translation a few seconds later.
/// Messages (text only, no raw audio) are relayed through the free public ntfy.sh service.
class TalkPage extends StatefulWidget {
  const TalkPage({super.key});
  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _Line {
  final bool mine;
  final String orig, tr;
  _Line(this.mine, this.orig, this.tr);
}

class _TalkPageState extends State<TalkPage> {
  static const _alpha = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String my = 'ar';
  String? partner;
  String code = '';
  bool inRoom = false;
  bool recording = false;
  bool busy = false;
  final codeCtl = TextEditingController();
  final lines = <_Line>[];
  final seen = <String>{};
  final uid = List.generate(10, (_) => _alpha[math.Random.secure().nextInt(_alpha.length)]).join();
  final mic = Mic();
  Timer? poll;
  int since = 0;
  String status = '';

  String get topic => 'nilo-talk-$code';

  String _newCode() => List.generate(8, (_) => _alpha[math.Random.secure().nextInt(_alpha.length)]).join();

  Future<void> _publish(Map<String, dynamic> m) async {
    m['u'] = uid;
    m['id'] = '${DateTime.now().microsecondsSinceEpoch}$uid';
    try {
      await http.post(Uri.parse('https://ntfy.sh/$topic'), body: utf8.encode(jsonEncode(m))).timeout(const Duration(seconds: 15));
    } catch (_) {
      if (mounted) setState(() => status = 'الرسالة ما اتبعتتش، تأكد من النت.');
    }
  }

  Future<void> _enter(String c) async {
    code = c.trim().toUpperCase();
    if (code.length < 6) {
      toast(context, 'الكود قصير');
      return;
    }
    since = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 20;
    setState(() {
      inRoom = true;
      status = 'مستني الطرف التاني يدخل بنفس الكود…';
    });
    await _publish({'t': 'hello', 'lang': my});
    poll = Timer.periodic(const Duration(milliseconds: 2000), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    try {
      final r = await http.get(Uri.parse('https://ntfy.sh/$topic/json?poll=1&since=$since')).timeout(const Duration(seconds: 10));
      for (final raw in utf8.decode(r.bodyBytes).split('\n')) {
        if (raw.trim().isEmpty) continue;
        final ev = jsonDecode(raw) as Map<String, dynamic>;
        if (ev['event'] != 'message') continue;
        final t = (ev['time'] as num?)?.toInt() ?? 0;
        if (t > since) since = t;
        Map<String, dynamic> m;
        try {
          m = jsonDecode(ev['message'].toString()) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final id = (m['id'] ?? '').toString();
        if (m['u'] == uid || id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        if (m['t'] == 'hello') {
          final first = partner == null;
          partner = (m['lang'] ?? 'en').toString();
          if (first) {
            await _publish({'t': 'hello', 'lang': my});
          }
          if (mounted) setState(() => status = 'الطرف التاني دخل (${_name(partner!)}). دوس الزرار وكلّم.');
        } else if (m['t'] == 'msg') {
          final tr = (m['tr'] ?? '').toString();
          final orig = (m['orig'] ?? '').toString();
          if (tr.isEmpty) continue;
          if (mounted) setState(() => lines.add(_Line(false, orig, tr)));
          speak(tr, my);
        }
      }
    } catch (_) {}
  }

  String _name(String c) {
    final i = kCodes.indexOf(c);
    return i >= 0 ? kNames[i] : c;
  }

  Future<void> _talk() async {
    if (partner == null) {
      toast(context, 'لسه الطرف التاني ما دخلش');
      return;
    }
    if (!recording) {
      if (!await mic.start()) {
        if (mounted) toast(context, 'محتاج إذن الميكروفون');
        return;
      }
      setState(() => recording = true);
      return;
    }
    setState(() {
      recording = false;
      busy = true;
    });
    final b = await mic.stop();
    if (b == null || b.isEmpty) {
      setState(() => busy = false);
      return;
    }
    final res = await trAudio(b, 'audio/mp4', my, partner!);
    if (!mounted) return;
    if (res.ok) {
      setState(() => lines.add(_Line(true, res.original, res.translation)));
      await _publish({'t': 'msg', 'lang': my, 'orig': res.original, 'tr': res.translation});
    } else {
      toast(context, res.empty ? 'ما سمعتش كلام واضح، جرب تاني' : (res.error.isEmpty ? 'الترجمة فشلت' : res.error));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    poll?.cancel();
    mic.dispose();
    codeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مكالمة مترجمة • Live talk'), backgroundColor: kBg),
      body: inRoom ? _room() : _lobby(),
    );
  }

  Widget _lobby() => ListView(padding: const EdgeInsets.all(18), children: [
        const Text('كل واحد على موبايله. واحد يعمل غرفة ويبعت الكود للتاني، والتاني يدخل بيه. بتتكلم، والتاني يسمع ترجمتك بلغته بعد ثواني.', style: TextStyle(height: 1.5)),
        const SizedBox(height: 8),
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Turn-based, not instant: each sentence takes a few seconds. Needs internet on both phones. Text (not your voice) goes through the free public ntfy.sh relay, so anyone who guesses the room code could read it. Do not share private details.', style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4)),
        ),
        const SizedBox(height: 16),
        const Text('لغتك'),
        DropdownButton<String>(
          isExpanded: true,
          value: my,
          items: [for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(kNames[i]))],
          onChanged: (v) => setState(() => my = v ?? my),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
            onPressed: () => _enter(_newCode()),
            child: const Text('اعمل غرفة جديدة'),
          ),
        ),
        const SizedBox(height: 22),
        TextField(controller: codeCtl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'أو اكتب كود الغرفة', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        SizedBox(height: 48, child: OutlinedButton(onPressed: () => _enter(codeCtl.text), child: const Text('ادخل الغرفة'))),
      ]);

  Widget _room() => Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF12304D),
          child: Column(children: [
            Directionality(textDirection: TextDirection.ltr, child: SelectableText('كود الغرفة: $code', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kGreen, letterSpacing: 2))),
            Text(status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            for (final l in lines)
              Align(
                alignment: l.mine ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(color: l.mine ? const Color(0xFF1A3C5E) : kGreen.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.mine ? l.orig : l.tr, style: const TextStyle(fontSize: 16)),
                    Text(l.mine ? '← ${l.tr}' : l.orig, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ]),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: recording ? Colors.redAccent : kGreen, foregroundColor: Colors.black),
              onPressed: busy ? null : _talk,
              icon: Icon(recording ? Icons.stop : Icons.mic),
              label: Text(busy ? 'بترجم…' : (recording ? 'خلصت، ابعت' : 'دوس وكلّم')),
            ),
          ),
        ),
      ]);
}
