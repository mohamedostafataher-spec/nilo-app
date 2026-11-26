import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'world.dart';
import 'bottles.dart';
import 'screens.dart' show toast;
import 'extras.dart' show niloRoute;

const _bgs = <List<Color>>[
  [Color(0xFFE08A5B), Color(0xFF7A3E5A)],
  [Color(0xFF2E7BA6), Color(0xFF0E2A45)],
  [Color(0xFFD9A441), Color(0xFF8A5A12)],
  [Color(0xFF3F8F6B), Color(0xFF14423A)],
  [Color(0xFF7A5AA6), Color(0xFF2A1B4A)],
];

String _ago(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final m = DateTime.now().toUtc().difference(d.toUtc()).inMinutes;
  if (m < 1) return 'now';
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h';
}

String _flag(String code) {
  for (final w in kWorld) { if (w[0] == code) return w[3] as String; }
  return '🌍';
}

/// Daily stories: short text cards that vanish after 24 hours.
class StoriesTab extends StatefulWidget {
  const StoriesTab({super.key});
  @override
  State<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  bool busy = true, joined = false;
  String err = '';
  List<dynamic> l = [];
  String nick = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { busy = true; err = ''; });
    final p = await SharedPreferences.getInstance();
    nick = p.getString('b_nick') ?? '';
    joined = (p.getBool('b_age') ?? false) && nick.isNotEmpty;
    if (!joined) { if (mounted) setState(() => busy = false); return; }
    try {
      if (!await Sb.signIn()) throw Exception('No connection');
      _cleanup();
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
      final r = await Sb.get('stories?select=*,story_reactions(emoji,user_id),story_comments(id)&created_at=gte.$since&order=created_at.desc&limit=60');
      l = r as List;
    } catch (e) {
      err = 'Could not load stories. Check your connection.';
    }
    if (mounted) setState(() => busy = false);
  }

  /// Crowd-sourced cleanup: any open app deletes files older than 25h, then expired rows.
  Future<void> _cleanup() async {
    try {
      final l = await Sb.rpc('expired_objects') as List;
      for (final n in l) { await Sb.removeFile(n.toString()); }
      await Sb.rpc('purge_rows');
    } catch (_) {}
  }

  Future<void> _write() async {
    final ok = await Navigator.of(context).push<bool>(niloRoute(StoryComposer(nick: nick)));
    if (ok == true) _load();
  }

  Future<void> _menu(Map s) async {
    final mine = s['author'] == Sb.uid;
    final v = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E2A45), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (mine) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete my story'), onTap: () => Navigator.pop(context, 'del'))
      else ...[
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report this story'), onTap: () => Navigator.pop(context, 'rep')),
        ListTile(leading: const Icon(Icons.block), title: const Text('Block this person'), onTap: () => Navigator.pop(context, 'blk')),
      ],
    ])));
    if (v == null) return;
    try {
      if (v == 'del') { await Sb.delete('stories?id=eq.${s['id']}'); if (s['media_path'] != null) await Sb.removeFile(s['media_path'].toString()); }
      if (v == 'rep') { await Sb.post('rpc/report_story', {'sid': s['id']}); if (mounted) toast(context, 'Reported. Thank you.'); }
      if (v == 'blk') { await Sb.post('blocks', {'blocker': Sb.uid, 'blocked': s['author']}); if (mounted) toast(context, 'Blocked.'); }
      _load();
    } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
  }

  Widget _media(Map s) {
    final url = Sb.publicUrl(s['media_path'].toString());
    if (s['media_type'] == 'video') return ClipView(url: url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(url, fit: BoxFit.cover, height: 300, width: double.infinity, errorBuilder: (_, __, ___) => const SizedBox(height: 80, child: Center(child: Text('Photo expired', style: TextStyle(color: Colors.white70))))),
    );
  }

  Widget _react(Map s, String e) {
    final rs = ((s['story_reactions'] ?? []) as List).where((r) => r['emoji'] == e).toList();
    final mine = rs.any((r) => r['user_id'] == Sb.uid);
    return ChoiceChip(
      selected: mine,
      backgroundColor: Colors.black26,
      selectedColor: Colors.white30,
      label: Text(rs.isEmpty ? e : '$e ${rs.length}'),
      onSelected: (_) async {
        try {
          if (mine) { await Sb.delete('story_reactions?story_id=eq.${s['id']}&user_id=eq.${Sb.uid}'); }
          else {
            await Sb.delete('story_reactions?story_id=eq.${s['id']}&user_id=eq.${Sb.uid}');
            await Sb.post('story_reactions', {'story_id': s['id'], 'user_id': Sb.uid, 'emoji': e});
          }
          _load();
        } catch (_) { if (mounted) toast(context, 'Did not work. Try again.'); }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('قصص اليوم • Daily stories'), backgroundColor: kBg, actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: joined ? FloatingActionButton.extended(onPressed: _write, backgroundColor: kGreen, foregroundColor: const Color(0xFF3B2A12), icon: const Icon(Icons.edit), label: const Text('Share a story')) : null,
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : !joined
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📖', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: 10),
                  const Text('Stories are for travelers 18 and older.\nJoin once to read and share.', textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () async { await Navigator.of(context).push(niloRoute(const BottlesPage())); _load(); }, child: const Text('Join • انضم')),
                ])))
              : err.isNotEmpty
                  ? Center(child: Text(err))
                  : l.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No stories yet today.\nBe the first. Stories disappear after 24 hours.', textAlign: TextAlign.center)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                          itemCount: l.length + 1,
                          itemBuilder: (_, i) {
                            if (i == l.length) return const Padding(padding: EdgeInsets.all(12), child: Text('Text only. Stories vanish after 24 hours. Tap ⋮ to report or block.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white54)));
                            final s = Map<String, dynamic>.from(l[i] as Map);
                            final c = _bgs[((s['mood'] ?? 0) as int) % _bgs.length];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c), borderRadius: BorderRadius.circular(20)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('${_flag((s['country'] ?? '').toString())} ${s['nick'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Text(_ago((s['created_at'] ?? '').toString()), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  const Spacer(),
                                  InkWell(onTap: () => _menu(s), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.more_vert, color: Colors.white70))),
                                ]),
                                const SizedBox(height: 10),
                                if (s['media_path'] != null) ...[_media(s), const SizedBox(height: 10)],
                                if (((s['body'] ?? '') as String).isNotEmpty)
                                Text((s['body'] ?? '').toString(), style: const TextStyle(fontSize: 19, height: 1.4, color: Colors.white, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  for (final e in const ['❤️', '😂', '😮', '👏', '🔥']) _react(s, e),
                                  ActionChip(
                                    backgroundColor: Colors.black26,
                                    label: Text('💬 ${((s['story_comments'] ?? []) as List).length}'),
                                    onPressed: () => Navigator.of(context).push(niloRoute(CommentsPage(story: s))),
                                  ),
                                ]),
                              ]),
                            );
                          },
                        ),
    );
  }
}

class StoryComposer extends StatefulWidget {
  final String nick;
  const StoryComposer({super.key, required this.nick});
  @override
  State<StoryComposer> createState() => _StoryComposerState();
}

class _StoryComposerState extends State<StoryComposer> {
  final c = TextEditingController();
  int mood = 0;
  bool busy = false, mediaOk = true;
  String status = '';
  List<int>? bytes;
  String? mime, ext, info;

  @override
  void initState() {
    super.initState();
    Sb.rpc('storage_ok').then((v) { if (mounted) setState(() => mediaOk = v == true); }).catchError((_) {});
  }

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1080, maxHeight: 1080, imageQuality: 70);
      if (x == null) return;
      final b = await x.readAsBytes();
      if (b.length > 5 * 1024 * 1024) { if (mounted) toast(context, 'Photo too large.'); return; }
      setState(() { bytes = b; mime = 'image/jpeg'; ext = 'jpg'; info = 'Photo ready (${(b.length / 1024).round()} KB)'; });
    } catch (_) { if (mounted) toast(context, 'Could not open the photo.'); }
  }

  Future<void> _pickClip(ImageSource src) async {
    try {
      final x = await ImagePicker().pickVideo(source: src, maxDuration: const Duration(seconds: 15));
      if (x == null) return;
      setState(() { busy = true; status = 'Making the clip small...'; });
      final m = await VideoCompress.compressVideo(x.path, quality: VideoQuality.LowQuality, deleteOrigin: false, includeAudio: true);
      final f = m?.file;
      if (f == null) throw Exception('compress');
      final b = await File(f.path).readAsBytes();
      if (b.length > 5 * 1024 * 1024) { setState(() { busy = false; status = ''; }); if (mounted) toast(context, 'Clip too big. Record up to 15 seconds.'); return; }
      if ((m?.duration ?? 0) > 16000) { setState(() { busy = false; status = ''; }); if (mounted) toast(context, 'Max 15 seconds.'); return; }
      setState(() { bytes = b; mime = 'video/mp4'; ext = 'mp4'; busy = false; status = ''; info = 'Clip ready (${(b.length / 1024 / 1024).toStringAsFixed(1)} MB)'; });
    } catch (_) {
      if (mounted) { setState(() { busy = false; status = ''; }); toast(context, 'Could not prepare the clip.'); }
    }
  }

  void _sheet(bool clip) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0E2A45), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_camera), title: Text(clip ? 'Record a clip (max 15s)' : 'Take a photo'), onTap: () { Navigator.pop(context); clip ? _pickClip(ImageSource.camera) : _pickPhoto(ImageSource.camera); }),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from gallery'), onTap: () { Navigator.pop(context); clip ? _pickClip(ImageSource.gallery) : _pickPhoto(ImageSource.gallery); }),
    ])));
  }

  Future<void> _post() async {
    final t = c.text.trim();
    if (bytes == null && t.length < 3) { toast(context, 'Write a little more, or add a photo or clip.'); return; }
    final bad = RegExp(r'(https?://|www\.|\.com|\.net|\.org|@|t\.me|wa\.me)').hasMatch(t.toLowerCase())
        ? 'No links or @ handles.'
        : RegExp(r'[0-9٠-٩]{6,}').hasMatch(t) ? 'No phone numbers.' : '';
    if (bad.isNotEmpty) { toast(context, bad); return; }
    setState(() { busy = true; status = 'Posting...'; });
    try {
      String? path;
      if (bytes != null) {
        path = '${Sb.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        if (!await Sb.upload(path, bytes!, mime!)) throw Exception('upload');
      }
      await Sb.post('stories', {'author': Sb.uid, 'nick': widget.nick, 'country': Passport.country, 'body': t, 'mood': mood, if (path != null) 'media_path': path, if (path != null) 'media_type': mime == 'video/mp4' ? 'video' : 'image'});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() { busy = false; status = ''; }); toast(context, '$e'.contains('limit') ? 'Daily limit reached: 3 photo/clip stories and 6 stories per day.' : 'Could not post. Try again.'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _bgs[mood];
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('New story'), backgroundColor: kBg),
      body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16), height: 200,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: col), borderRadius: BorderRadius.circular(20)),
          child: TextField(controller: c, maxLength: 200, maxLines: null, expands: true, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'What happened today?', hintStyle: TextStyle(color: Colors.white60))),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _bgs.length; i++)
            GestureDetector(onTap: () => setState(() => mood = i), child: Container(margin: const EdgeInsets.all(6), width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: _bgs[i]), border: Border.all(color: mood == i ? Colors.white : Colors.transparent, width: 3)))),
        ]),
        const SizedBox(height: 6),
        if (mediaOk)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(onPressed: busy ? null : () => _sheet(false), icon: const Icon(Icons.image), label: const Text('Photo')),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: busy ? null : () => _sheet(true), icon: const Icon(Icons.videocam), label: const Text('Clip (15s)')),
          ])
        else
          const Text('Photos and clips are paused today (storage is full). Text stories still work.', textAlign: TextAlign.center, style: TextStyle(color: Colors.amber)),
        if (info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('✓ $info', style: const TextStyle(color: kGreen, fontWeight: FontWeight.w700))),
        const SizedBox(height: 10),
        const Text('Visible for 24 hours. Photos and clips are shown to other adults, so no nudity, no minors, no private or ID documents. Anyone can report; a reported photo or clip is hidden at once. Your country flag is shown, never your location. Limit: 3 photo/clip stories and 6 stories per day.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : _post, child: Text(busy ? (status.isEmpty ? '...' : status) : 'Post story'))),
      ])),
    );
  }
}

class ClipView extends StatefulWidget {
  final String url;
  const ClipView({super.key, required this.url});
  @override
  State<ClipView> createState() => _ClipViewState();
}

class _ClipViewState extends State<ClipView> {
  VideoPlayerController? v;
  bool loading = false;
  @override
  void dispose() { v?.dispose(); super.dispose(); }
  Future<void> _start() async {
    if (v != null) { v!.value.isPlaying ? await v!.pause() : await v!.play(); setState(() {}); return; }
    setState(() => loading = true);
    try {
      v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await v!.initialize();
      v!.setLooping(true);
      await v!.play();
    } catch (_) { v = null; }
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    final ready = v != null && v!.value.isInitialized;
    return GestureDetector(
      onTap: _start,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 300, width: double.infinity, color: Colors.black38,
          child: ready
              ? FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: v!.value.size.width, height: v!.value.size.height, child: VideoPlayer(v!)))
              : Center(child: loading ? const CircularProgressIndicator() : const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_circle_fill, size: 64, color: Colors.white), Text('Tap to play clip', style: TextStyle(color: Colors.white70))])),
        ),
      ),
    );
  }
}

class CommentsPage extends StatefulWidget {
  final Map story;
  const CommentsPage({super.key, required this.story});
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  List<dynamic> l = [];
  bool busy = true;
  final c = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      l = await Sb.get('story_comments?select=*&story_id=eq.${widget.story['id']}&order=created_at.asc&limit=100') as List;
    } catch (_) {}
    if (mounted) setState(() => busy = false);
  }

  Future<void> _send() async {
    final t = c.text.trim();
    if (t.isEmpty) return;
    final bad = RegExp(r'(https?://|www\.|\.com|\.net|\.org|@|t\.me|wa\.me)').hasMatch(t.toLowerCase())
        ? 'No links or @ handles.'
        : RegExp(r'[0-9٠-٩]{6,}').hasMatch(t) ? 'No phone numbers.' : '';
    if (bad.isNotEmpty) { toast(context, bad); return; }
    final p = await SharedPreferences.getInstance();
    try {
      await Sb.post('story_comments', {'story_id': widget.story['id'], 'author': Sb.uid, 'nick': p.getString('b_nick') ?? '', 'country': Passport.country, 'body': t});
      c.clear();
      _load();
    } catch (_) { if (mounted) toast(context, 'Could not send.'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(title: const Text('Comments'), backgroundColor: kBg),
        body: Column(children: [
          Expanded(
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? const Center(child: Text('No comments yet.'))
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final m in l)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${_flag((m['country'] ?? '').toString())} ${m['nick'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                              const SizedBox(height: 4),
                              Text((m['body'] ?? '').toString()),
                            ]),
                          ),
                      ]),
          ),
          SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: TextField(controller: c, maxLength: 200, decoration: const InputDecoration(counterText: '', hintText: 'Write a comment (no links or numbers)'))),
            IconButton(onPressed: _send, icon: const Icon(Icons.send, color: kGreen)),
          ]))),
        ]),
      );
}
