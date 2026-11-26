import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'main.dart';
import 'net.dart';
import 'screens.dart';

/// Phrasebook for a visitor: you read the meaning in YOUR language,
/// and show / play the phrase in the language of the person you talk to.
class PhrasebookPage extends StatefulWidget {
  final Map<String, List<String>> data;
  final String title;
  const PhrasebookPage({super.key, this.data = kPhrases, this.title = 'Phrasebook • عبارات'});
  @override
  State<PhrasebookPage> createState() => _PhrasebookPageState();
}

class _PhrasebookPageState extends State<PhrasebookPage> {
  String me = 'en'; // my language (meaning)
  String they = 'ar'; // language shown/played to the other person
  late String cat = widget.data.keys.first;
  final cache = <String, String>{};
  bool loading = false;
  SharedPreferences? _p;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _p = await SharedPreferences.getInstance();
    me = _p!.getString('pb_me') ?? 'en';
    they = _p!.getString('pb_they') ?? 'ar';
    final raw = _p!.getString('pb_cache');
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) => cache[k] = v.toString());
      } catch (_) {}
    }
    if (mounted) setState(() {});
    _fill();
  }

  String _key(String ar, String to) => '$to|$ar';

  String _text(String ar, String lang) => lang == 'ar' ? ar : (cache[_key(ar, lang)] ?? '');

  Future<void> _fill() async {
    final list = widget.data[cat]!;
    setState(() => loading = true);
    var changed = false;
    for (final ar in list) {
      for (final lang in {me, they}) {
        if (lang == 'ar' || cache.containsKey(_key(ar, lang))) continue;
        final r = await trText(ar, 'ar', lang);
        if (!mounted) return;
        if (r.ok) {
          cache[_key(ar, lang)] = r.translation;
          changed = true;
          setState(() {});
        } else {
          setState(() => loading = false);
          toast(context, r.error.isEmpty ? 'الترجمة مش متاحة دلوقتي' : r.error);
          if (changed) _save();
          return;
        }
      }
    }
    if (changed) _save();
    if (mounted) setState(() => loading = false);
  }

  void _save() => _p?.setString('pb_cache', jsonEncode(cache));

  void _set({String? m, String? t, String? c}) {
    setState(() {
      if (m != null) me = m;
      if (t != null) they = t;
      if (c != null) cat = c;
    });
    _p?.setString('pb_me', me);
    _p?.setString('pb_they', they);
    _fill();
  }

  Widget _drop(String label, String value, void Function(String) on) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          DropdownButton<String>(
            isExpanded: true,
            value: value,
            items: [for (var i = 0; i < kCodes.length; i++) DropdownMenuItem(value: kCodes[i], child: Text(kNames[i], overflow: TextOverflow.ellipsis))],
            onChanged: (v) => v == null ? null : on(v),
          ),
        ]),
      );

  void _show(String ar) {
    final big = _text(ar, they);
    final mean = _text(ar, me);
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Align(alignment: Alignment.topLeft, child: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context))),
              Expanded(
                child: Center(
                  child: Text(big, textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
              Text(mean, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: kNavyBtn, foregroundColor: Colors.white),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Play • شغّل'),
                  onPressed: () => speak(big, they),
                ),
              ),
            ]),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.data[cat]!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          _drop('I speak • لغتي', me, (v) => _set(m: v)),
          const SizedBox(width: 12),
          _drop('Show to them in • لغة الطرف التاني', they, (v) => _set(t: v)),
        ]),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in widget.data.keys)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(label: Text(c), selected: c == cat, onSelected: (_) => _set(c: c)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        for (final ar in list)
          Card(
            color: const Color(0xFF12304D),
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_text(ar, me).isEmpty ? '…' : _text(ar, me), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(_text(ar, they).isEmpty ? '…' : _text(ar, they), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
                    onPressed: _text(ar, they).isEmpty ? null : () async { if (!await speak(_text(ar, they), they) && mounted) toast(context, 'الجهاز مفيهوش صوت للغة دي'); },
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: const Text('Play'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _text(ar, they).isEmpty ? null : () => _show(ar),
                    icon: const Icon(Icons.fullscreen, size: 18),
                    label: const Text('Show big'),
                  ),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        const Text('الجمل الأصلية بالمصري كتبتها أنا ومترجمتش مع متحدث. الترجمة آلية وبتتحفظ بعد أول مرة. راجع الطوارئ والحساسية.\nPhrases are machine-translated from Egyptian Arabic and cached after the first load. Double-check emergencies and allergies.', style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4)),
      ]),
    );
  }
}

const kNavyBtn = Color(0xFF0E2A47);
