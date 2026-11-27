import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'world.dart' show Passport;
import 'i18n.dart';

/// Real AdMob ids (not secrets, they ship inside every app). Ads are only ever
/// shown inside the Store page: one opt-in rewarded ad the user taps, and one
/// small native ad. Never on app open, never during play, never a popup.
class Ads {
  static const rewardedId = 'ca-app-pub-4446395628942302/8607240916';
  static const nativeId = 'ca-app-pub-4446395628942302/7645513031';
  static const dailyCap = 5; // rewarded ads per day
  static const rewardReeds = 5;
  static bool _init = false;

  static Future<void> init() async {
    if (_init) return;
    _init = true;
    try {
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        maxAdContentRating: MaxAdContentRating.pg,
      ));
      await MobileAds.instance.initialize();
    } catch (_) {}
  }

  static const _req = AdRequest(nonPersonalizedAds: true);

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  static Future<int> usedToday() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('ad_day') == _today() ? (p.getInt('ad_n') ?? 0) : 0;
  }

  static Future<void> _count() async {
    final p = await SharedPreferences.getInstance();
    final n = await usedToday();
    await p.setString('ad_day', _today());
    await p.setInt('ad_n', n + 1);
  }

  /// Loads and shows a rewarded ad. Returns true if Reeds were granted.
  static Future<String> watchRewarded() async {
    await init();
    if (await usedToday() >= dailyCap) return 'cap';
    final done = Completer<String>();
    RewardedAd.load(
      adUnitId: rewardedId,
      request: _req,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          bool earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) { a.dispose(); if (!done.isCompleted) done.complete(earned ? 'ok' : 'skipped'); },
            onAdFailedToShowFullScreenContent: (a, e) { a.dispose(); if (!done.isCompleted) done.complete('none'); },
          );
          ad.show(onUserEarnedReward: (_, __) async { earned = true; Passport.addReeds(rewardReeds); await _count(); });
        },
        onAdFailedToLoad: (e) { if (!done.isCompleted) done.complete('none'); },
      ),
    );
    return done.future.timeout(const Duration(seconds: 45), onTimeout: () => 'none');
  }
}

/// One small native ad. Shows nothing until Google actually returns an ad.
class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});
  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    Ads.init().then((_) {
      if (!mounted) return;
      _ad = NativeAd(
        adUnitId: Ads.nativeId,
        request: Ads._req,
        nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.small),
        listener: NativeAdListener(
          onAdLoaded: (_) { if (mounted) setState(() => _ok = true); },
          onAdFailedToLoad: (ad, e) { ad.dispose(); _ad = null; },
        ),
      )..load();
    });
  }

  @override
  void dispose() { _ad?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_ok || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 100,
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AdWidget(ad: _ad!)),
    );
  }
}
