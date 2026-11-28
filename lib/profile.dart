import 'health.dart';
import 'i18n.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'world.dart' show Passport;
import 'bottles.dart' show Sb;
import 'screens.dart' show toast;
import 'gender.dart';
import 'gallery.dart';
import 'circles.dart' show niloJoined;

const kAvatars = ['🦊', '🐼', '🐯', '🦁', '🐸', '🐙', '🦉', '🐧', '🦄', '🐲', '🐨', '🐰', '🦋', '🐢', '🦒', '🐘', '🐬', '🦅', '🐝', '🐱', '🐶', '🐵', '🦜', '🐪'];
const _bg = [Color(0xFFD9A441), Color(0xFF3FA796), Color(0xFF7B5EA7), Color(0xFFD1604D), Color(0xFF4B8BBE), Color(0xFF6BA368)];

/// Round avatar: uploaded photo (if any and not hidden), else a built-in cartoon, else a neutral glyph.
class AvatarView extends StatelessWidget {
  final String avatar, path;
  final double size;
  const AvatarView({super.key, this.avatar = '', this.path = '', this.size = 64});
  @override
  Widget build(BuildContext context) {
    final i = avatar.isEmpty ? 0 : kAvatars.indexOf(avatar).clamp(0, kAvatars.length - 1);
    final c = _bg[i % _bg.length];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kGreen, width: 2),
          gradient: LinearGradient(colors: [c, c.withOpacity(0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: path.isNotEmpty
          ? Image.network(Sb.publicUrl(path), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text(avatar.isEmpty ? '🙂' : avatar, style: TextStyle(fontSize: size * 0.5)))
          : Text(avatar.isEmpty ? '🙂' : avatar, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Edit your own profile: cartoon avatar or photo, display name, short bio.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final bio = TextEditingController(), nick = TextEditingController();
  String avatar = '', path = '', gender = '';
  bool busy = false;
  int? nFriends, nPhotos;

  @override
  void initState() {
    super.initState();
    nick.addListener(() { if (mounted) setState(() {}); });
    _stats();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() { avatar = p.getString('p_avatar') ?? ''; path = p.getString('p_avatar_path') ?? ''; bio.text = p.getString('p_bio') ?? ''; nick.text = Passport.nickname; gender = p.getString('p_gender') ?? ''; });
    });
  }

  Future<void> _stats() async {
    try {
      if (!await niloJoined()) return;
      await Sb.signIn();
      final f = (await Sb.rpc('my_friends') as List?) ?? [];
      final ph = (await Sb.get('profile_photos?select=id&uid=eq.${Sb.uid}') as List?) ?? [];
      if (mounted) setState(() { nFriends = f.where((x) => x['status'] == 'accepted').length; nPhotos = ph.length; });
    } catch (e, st) { Health.log(e, st); }
  }

  Widget _stat(String label, int? v, IconData ic) => Expanded(
        child: Column(children: [
          Icon(ic, size: 18, color: kGreen),
          const SizedBox(height: 4),
          Text(v == null ? '-' : '$v', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      );

  Widget _card(String title, IconData ic, List<Widget> kids) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(ic, size: 18, color: kGreen), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
          const SizedBox(height: 12),
          ...kids,
        ]),
      );

  String _badText(String s) {
    if (RegExp(r'(https?://|www\.|@|t\.me|wa\.me|\.com|\.net|\.org)', caseSensitive: false).hasMatch(s)) return L('No links or @ handles.');
    if (RegExp(r'[0-9٠-٩]{6,}').hasMatch(s)) return L('No phone numbers.');
    return '';
  }

  /// Decode and re-encode as a small PNG: drops EXIF/GPS and any other metadata.
  Future<Uint8List?> _clean(Uint8List raw) async {
    final codec = await ui.instantiateImageCodec(raw, targetWidth: 384);
    final f = await codec.getNextFrame();
    final bd = await f.image.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    setState(() => busy = true);
    try {
      final out = await _clean(await x.readAsBytes());
      if (out == null || out.length > 900 * 1024) throw Exception('size');
      final p = '${Sb.uid}/av_${DateTime.now().millisecondsSinceEpoch}.png';
      if (!await Sb.upload(p, out, 'image/png')) throw Exception('upload');
      if (mounted) setState(() => path = p);
    } catch (_) {
      if (mounted) toast(context, 'Could not use this photo. Try another.');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    final b = bio.text.trim();
    final bad = _badText(b);
    if (bad.isNotEmpty) { toast(context, bad); return; }
    setState(() => busy = true);
    if (nick.text.trim().isNotEmpty) Passport.nickname = nick.text.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('p_avatar', avatar); await p.setString('p_avatar_path', path); await p.setString('p_bio', b);
    if (gender.isNotEmpty) await Gender.set(gender);
    try {
      await Sb.rpc('set_profile', {'p_bio': b, 'p_avatar': avatar, 'p_avatar_path': path});
      if (mounted) { toast(context, 'Saved'); Navigator.pop(context, true); }
    } catch (_) {
      if (mounted) { toast(context, 'Saved on this phone. It will show to others once you have joined Papyrus and are online.'); setState(() => busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = nick.text.trim().isEmpty ? L('Traveler') : nick.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text(L('Profile • الملف')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        // Cover + avatar
        SizedBox(height: 208, child: Stack(alignment: Alignment.bottomCenter, children: [
          Positioned(top: 0, left: 0, right: 0, child: Container(
            height: 150,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kGreen.withOpacity(0.55), const Color(0xFF1B3B5A), kBg])),
            child: Align(alignment: Alignment.topRight, child: Padding(padding: const EdgeInsets.all(14), child: Icon(Icons.explore, size: 64, color: Colors.white.withOpacity(0.10)))),
          )),
          Stack(children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBg, width: 5)), child: AvatarView(avatar: avatar, path: path, size: 116)),
            Positioned(right: 0, bottom: 4, child: GestureDetector(
              onTap: busy ? null : _photo,
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreen, shape: BoxShape.circle, border: Border.all(color: kBg, width: 3)),
                  child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.photo_camera, size: 16, color: Colors.black)),
            )),
          ]),
        ])),
        const SizedBox(height: 8),
        Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
        const SizedBox(height: 6),
        Center(child: Wrap(spacing: 8, children: [
          if (gender.isNotEmpty) Chip(visualDensity: VisualDensity.compact, avatar: Icon(gender == 'f' ? Icons.female : Icons.male, size: 16), label: Text(gender == 'f' ? L('Female • أنثى') : L('Male • ذكر'))),
          Chip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.verified_user, size: 16, color: kGreen), label: Text(L('18+ confirmed'))),
        ])),
        if (bio.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(28, 4, 28, 0), child: Text(bio.text.trim(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4))),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
          child: Row(children: [_stat(L('Friends'), nFriends, Icons.people), _stat(L('Photos'), nPhotos, Icons.photo_library)]),
        ),
        _card(L('Photo'), Icons.photo_camera, [
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(onPressed: busy ? null : _photo, icon: const Icon(Icons.photo_library), label: Text(L('Upload a photo'))),
            if (path.isNotEmpty) TextButton(onPressed: () => setState(() => path = ''), child: Text(L('Remove photo'))),
          ]),
          const SizedBox(height: 8),
          Text(L('Photos are shrunk and stripped of metadata (including location) before upload. Others can report a photo; reported photos are hidden. Faces of other people, minors and nudity are not allowed.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          Text(L('Or pick a cartoon'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in kAvatars)
              GestureDetector(
                onTap: () => setState(() { avatar = a; path = ''; }),
                child: Opacity(opacity: (avatar == a && path.isEmpty) ? 1 : 0.5, child: AvatarView(avatar: a, size: 50)),
              ),
          ]),
        ]),
        _card(L('Gallery'), Icons.collections, [const GalleryEditor()]),
        _card(L('About you'), Icons.person, [
          TextField(controller: nick, maxLength: 20, decoration: InputDecoration(labelText: L('Display name • الاسم'), hintText: L('No real name needed'), border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          Text(L('You are • أنت'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<String>(segments: [ButtonSegment(value: 'm', label: Text(L('Male • ذكر'))), ButtonSegment(value: 'f', label: Text(L('Female • أنثى')))], selected: gender.isEmpty ? <String>{} : {gender}, emptySelectionAllowed: true, onSelectionChanged: (v) => setState(() => gender = v.isEmpty ? '' : v.first)),
          const SizedBox(height: 14),
          TextField(controller: bio, maxLength: 160, maxLines: 3, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: L('About you (optional)'), hintText: L('A line about you. No links or phone numbers.'), border: const OutlineInputBorder())),
          const SizedBox(height: 4),
          Text(L('Your bio and avatar are visible to other adults (18+) on your profile card. Never share contact details.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(L('Save'))),
          ),
        ),
      ]),
    );
  }
}
