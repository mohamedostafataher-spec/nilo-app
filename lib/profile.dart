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
  String avatar = '', path = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() { avatar = p.getString('p_avatar') ?? ''; path = p.getString('p_avatar_path') ?? ''; bio.text = p.getString('p_bio') ?? ''; nick.text = Passport.nickname; });
    });
  }

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
      setState(() => path = p);
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
    try {
      await Sb.rpc('set_profile', {'p_bio': b, 'p_avatar': avatar, 'p_avatar_path': path});
      if (mounted) { toast(context, 'Saved'); Navigator.pop(context, true); }
    } catch (_) {
      if (mounted) { toast(context, 'Saved on this phone. It will show to others once you have joined Papyrus and are online.'); setState(() => busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(L('Profile • الملف')), backgroundColor: kBg),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: AvatarView(avatar: avatar, path: path, size: 110)),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            OutlinedButton.icon(onPressed: busy ? null : _photo, icon: const Icon(Icons.photo_library), label: Text(L('Upload a photo'))),
            if (path.isNotEmpty) TextButton(onPressed: () => setState(() => path = ''), child: Text(L('Remove photo'))),
          ]),
          const SizedBox(height: 6),
          Text(L('Photos are shrunk and stripped of metadata (including location) before upload. Others can report a photo; reported photos are hidden. Faces of other people, minors and nudity are not allowed.'), style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4)),
          const SizedBox(height: 14),
          Text(L('Or pick a cartoon'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in kAvatars)
              GestureDetector(
                onTap: () => setState(() { avatar = a; path = ''; }),
                child: Opacity(opacity: (avatar == a && path.isEmpty) ? 1 : 0.55, child: AvatarView(avatar: a, size: 52)),
              ),
          ]),
          const SizedBox(height: 18),
          TextField(controller: nick, maxLength: 20, decoration: InputDecoration(labelText: L('Display name • الاسم'), hintText: L('No real name needed'), border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: bio, maxLength: 160, maxLines: 3, decoration: InputDecoration(labelText: L('About you (optional)'), hintText: L('A line about you. No links or phone numbers.'), border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          Text(L('Your bio and avatar are visible to other adults (18+) on your profile card. Never share contact details.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 14),
          FilledButton(onPressed: busy ? null : _save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(L('Save')))),
        ]),
      );
}
