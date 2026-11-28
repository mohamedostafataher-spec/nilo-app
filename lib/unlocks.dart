import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ads.dart';
import 'i18n.dart';
import 'world.dart' show Passport;

/// Cosmetics unlocked by watching an optional rewarded ad. Real achievements (stamps, XP) are never sold for ads.
class Cosmetic {
  final String id, en, ar;
  final Color color;
  const Cosmetic(this.id, this.en, this.ar, this.color);
}

const kSealColors = <Cosmetic>[
  Cosmetic('red', 'Red wax', 'شمع أحمر', Color(0xFFB02A1E)),
  Cosmetic('blue', 'Blue wax', 'شمع أزرق', Color(0xFF1E4FB0)),
  Cosmetic('green', 'Green wax', 'شمع أخضر', Color(0xFF1E8A4A)),
  Cosmetic('gold', 'Gold wax', 'شمع دهبي', Color(0xFFC9A227)),
  Cosmetic('black', 'Black wax', 'شمع أسود', Color(0xFF222222)),
  Cosmetic('purple', 'Purple wax', 'شمع بنفسجي', Color(0xFF6A2AA0)),
];

const kCardFrames = <Cosmetic>[
  Cosmetic('papyrus', 'Papyrus', 'بردي', Color(0xFF7A5A1E)),
  Cosmetic('nile', 'Nile blue', 'أزرق النيل', Color(0xFF1E5AA0)),
  Cosmetic('palm', 'Palm green', 'أخضر النخيل', Color(0xFF2E7D4A)),
  Cosmetic('gold', 'Gold', 'دهبي', Color(0xFFC9A227)),
  Cosmetic('night', 'Night', 'ليل', Color(0xFF222B3A)),
];

class Unlocks {
  /// How many items of a kind are open (the first one is always free).
  static Future<int> count(String kind) async => (await SharedPreferences.getInstance()).getInt('un_$kind') ?? 1;
  static Future<int> selected(String kind) async => (await SharedPreferences.getInstance()).getInt('un_sel_$kind') ?? 0;
  static Future<void> select(String kind, int i) async => (await SharedPreferences.getInstance()).setInt('un_sel_$kind', i);
  static Future<void> unlockNext(String kind, int max) async {
    final p = await SharedPreferences.getInstance();
    final n = p.getInt('un_$kind') ?? 1;
    if (n < max) await p.setInt('un_$kind', n + 1);
  }
  static Future<Color> sealColor() async {
    final i = await selected('seal'), n = await count('seal');
    return kSealColors[(i < n ? i : 0).clamp(0, kSealColors.length - 1)].color;
  }
  static Future<Color> frameColor() async {
    final i = await selected('frame'), n = await count('frame');
    return kCardFrames[(i < n ? i : 0).clamp(0, kCardFrames.length - 1)].color;
  }
}

/// Store section: each optional ad unlocks one thing. Shared daily cap of rewarded ads (Ads.dailyCap).
class RewardSection extends StatefulWidget {
  const RewardSection({super.key});
  @override
  State<RewardSection> createState() => _RewardSectionState();
}

class _RewardSectionState extends State<RewardSection> {
  int seals = 1, frames = 1, selSeal = 0, selFrame = 0, used = 0;
  bool busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final a = await Unlocks.count('seal'), b = await Unlocks.count('frame'), c = await Unlocks.selected('seal'), d = await Unlocks.selected('frame'), u = await Ads.usedToday();
    if (mounted) setState(() { seals = a; frames = b; selSeal = c; selFrame = d; used = u; });
  }

  Future<void> _ad(String what, void Function() grant) async {
    if (busy) return;
    setState(() => busy = true);
    final r = await Ads.watchRewarded(reeds: false, onReward: grant);
    if (!mounted) return;
    setState(() => busy = false);
    final m = r == 'ok' ? 'Unlocked: $what. • اتفتح' : r == 'cap' ? 'That is today\'s limit (${Ads.dailyCap}). Come back tomorrow. • خلص حد النهاردة' : r == 'skipped' ? 'No reward, the ad was closed early. • اتقفل بدري' : 'No ad available right now. Try later. • مفيش إعلان دلوقتي';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L(m))));
    await _load();
  }

  Widget _chips(String kind, List<Cosmetic> list, int open, int sel) => Wrap(spacing: 6, runSpacing: 4, children: [
    for (var i = 0; i < list.length; i++)
      ChoiceChip(
        avatar: CircleAvatar(backgroundColor: list[i].color, radius: 8),
        label: Text(L(i < open ? '${list[i].en} • ${list[i].ar}' : 'Locked • مقفول'), style: const TextStyle(fontSize: 11)),
        selected: i < open && sel == i,
        onSelected: i < open ? (_) async { await Unlocks.select(kind, i); await _load(); } : null,
      ),
  ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('Watch an optional ad, unlock something • شاهد إعلان واكسب حاجة'), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(L('Rewarded ads used today: $used of ${Ads.dailyCap}. Never forced. • الإعلانات النهاردة $used من ${Ads.dailyCap}'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 8),
        ListTile(
          dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.water),
          title: Text(L('+1 extra papyrus catch today • بردية زيادة النهاردة')),
          subtitle: Text(L('You have ${Passport.catchesLeft} catches left today.')),
          trailing: FilledButton(onPressed: busy ? null : () => _ad('+1 catch', () => Passport.addCatch(1)), child: Text(L('Watch • شاهد'))),
        ),
        const Divider(),
        Text(L('Wax seal colour • لون ختم الشمع'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        _chips('seal', kSealColors, seals, selSeal),
        if (seals < kSealColors.length) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => _ad('new wax colour', () => Unlocks.unlockNext('seal', kSealColors.length)), child: Text(L('Watch an ad to unlock the next colour • افتح لون')))),
        const Divider(),
        Text(L('Name card frame • إطار كارت الاسم'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        _chips('frame', kCardFrames, frames, selFrame),
        if (frames < kCardFrames.length) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : () => _ad('new card frame', () => Unlocks.unlockNext('frame', kCardFrames.length)), child: Text(L('Watch an ad to unlock the next frame • افتح إطار')))),
        const SizedBox(height: 4),
        Text(L('Stamps, XP and achievements cannot be bought with ads. • الأختام والإنجازات مش بتتباع بإعلانات.'), style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ]),
    );
  }
}
