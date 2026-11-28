import 'health.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'i18n.dart';
import 'bottles.dart' show Sb;
import 'screens.dart' show toast;

/// Private-by-default photo gallery (max 6). Each photo has its own public/private switch.
class GalleryEditor extends StatefulWidget {
  const GalleryEditor({super.key});
  @override
  State<GalleryEditor> createState() => _GalleryEditorState();
}

class _GalleryEditorState extends State<GalleryEditor> {
  List<Map<String, dynamic>> rows = [];
  final Map<String, String> urls = {};
  bool busy = false, loaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await Sb.get('profile_photos?select=id,path,is_public&uid=eq.${Sb.uid}&order=created_at.asc') as List;
      rows = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final x in rows) {
        final u = await Sb.galSigned(x['path'].toString());
        if (u != null) urls[x['path'].toString()] = u;
      }
    } catch (e, st) { Health.log(e, st); }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> _add() async {
    if (rows.length >= 6) { toast(context, L('Maximum 6 photos.')); return; }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    setState(() => busy = true);
    try {
      final raw = await x.readAsBytes();
      final codec = await ui.instantiateImageCodec(raw, targetWidth: 900);
      final f = await codec.getNextFrame();
      final bd = await f.image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? out = bd?.buffer.asUint8List();
      if (out == null || out.length > 2800 * 1024) throw Exception('size');
      final p = '${Sb.uid}/g_${DateTime.now().millisecondsSinceEpoch}.png';
      if (!await Sb.galUpload(p, out, 'image/png')) throw Exception('upload');
      try {
        await Sb.post('profile_photos', {'uid': Sb.uid, 'path': p, 'is_public': false});
      } catch (e) {
        await Sb.galRemove(p);
        rethrow;
      }
      await _load();
    } catch (_) {
      if (mounted) toast(context, L('Could not add this photo. Try another.'));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _toggle(Map<String, dynamic> x, bool v) async {
    try {
      final r = await Sb.patch('profile_photos?id=eq.${x['id']}', {'is_public': v});
      if (r) setState(() => x['is_public'] = v);
    } catch (_) { if (mounted) toast(context, L('Could not change this. Check your connection.')); }
  }

  Future<void> _del(Map<String, dynamic> x) async {
    try {
      await Sb.delete('profile_photos?id=eq.${x['id']}');
      await Sb.galRemove(x['path'].toString());
      rows.remove(x);
      if (mounted) setState(() {});
    } catch (_) { if (mounted) toast(context, L('Could not delete. Check your connection.')); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(L('Photo gallery (max 6)'), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(L('Every photo is private until you switch it to public. Public photos can be seen by adults (18+) on your profile.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      const SizedBox(height: 8),
      if (loaded && rows.isEmpty) Text(L('No photos yet.'), style: const TextStyle(color: Colors.white54)),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final x in rows)
          SizedBox(width: 104, child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 104, height: 104, child: urls[x['path']] == null ? Container(color: Colors.white10) : Image.network(urls[x['path']]!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10)))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon((x['is_public'] == true) ? Icons.public : Icons.lock, size: 16, color: Colors.white70),
              Transform.scale(scale: 0.75, child: Switch(value: x['is_public'] == true, onChanged: (v) => _toggle(x, v))),
              InkWell(onTap: () => _del(x), child: const Icon(Icons.delete_outline, size: 18, color: Colors.white54)),
            ]),
          ])),
      ]),
      const SizedBox(height: 6),
      OutlinedButton.icon(onPressed: busy ? null : _add, icon: const Icon(Icons.add_a_photo), label: Text(L('Add photo'))),
      const SizedBox(height: 6),
      Text(L('Photos are shrunk and stripped of metadata. No faces of minors, no nudity, no contact details. Others can report a photo.'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
    ]);
  }
}

/// Shows only the photos another person made public.
class PeerGallery extends StatefulWidget {
  final String uid;
  const PeerGallery({super.key, required this.uid});
  @override
  State<PeerGallery> createState() => _PeerGalleryState();
}

class _PeerGalleryState extends State<PeerGallery> {
  final List<String> urls = [];
  bool done = false;

  @override
  void initState() { super.initState(); _go(); }

  Future<void> _go() async {
    try {
      final r = await Sb.rpc('get_public_photos', {'p_uid': widget.uid}) as List;
      for (final x in r) {
        final u = await Sb.galSigned((x['path'] ?? '').toString());
        if (u != null) urls.add(u);
      }
    } catch (e, st) { Health.log(e, st); }
    if (mounted) setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!done || urls.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(L('Photos'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 8),
      SizedBox(height: 120, child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final u in urls)
          Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(u)))),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(u, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, color: Colors.white10))),
          )),
      ])),
    ]);
  }
}
