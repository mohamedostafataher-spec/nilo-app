import 'health.dart';
import 'analytics.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'world.dart' show Passport;
import 'i18n.dart';

/// Real AdMob ids (not secrets, they ship inside every app). Ads are only ever
/// shown inside the Store page: one opt-in rewarded ad the user taps, and one
/// small native ad. Never on app open, never during play, never a popup.
class Ads {
  /// Config slots. Keep false for releases: real ids below. Set true ONLY for a private debug build (Google's test units, never shipped).
  /// The interstitial slot is empty until the real unit id is filled in, so no interstitial is shown before that.
  static const useTestUnits = false;
  static const _realRewarded = 'ca-app-pub-4446395628942302/8607240916';
  static const _realNative = 'ca-app-pub-4446395628942302/7645513031';
  static const _realInterstitial = 'ca-app-pub-4446395628942302/3148341155';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static String get rewardedId => useTestUnits ? _testRewarded : _realRewarded;
  static String get nativeId => useTestUnits ? _testNative : _realNative;
  static String get interstitialId => useTestUnits ? _testInterstitial : _realInterstitial;
  // Defaults; overridden by the remote config (nilo-dl/ads_config.json, a free static file) without an app update.
  static int interMinGapMin = 30, interDailyCap = 4;
  static bool interstitialOn = true, rewardedOn = true, nativeOn = true;
  static const configUrl = 'https://mohamedostafataher-spec.github.io/nilo-dl/ads_config.json';

  /// Pure rule, unit-tested: may an interstitial be shown now?
  static bool interAllowed({required int nowMs, required int lastMs, required int shownToday, required int gapMin, required int dailyCap}) =>
      shownToday < dailyCap && nowMs - lastMs >= gapMin * 60000;

  static void applyConfig(Map c) {
    int i(String k, int d, int lo, int hi) { final v = c[k]; return v is num ? v.toInt().clamp(lo, hi) : d; }
    bool b(String k, bool d) { final v = c[k]; return v is bool ? v : d; }
    interMinGapMin = i('inter_gap_min', 30, 5, 1440);
    interDailyCap = i('inter_daily', 4, 0, 20);
    dailyCap = i('rewarded_daily', 5, 0, 20);
    interstitialOn = b('interstitial', true);
    rewardedOn = b('rewarded', true);
    nativeOn = b('native', true);
  }

  /// Reads the remote caps (cached 6 h). Any failure keeps the safe defaults above.
  static Future<void> loadConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      final at = p.getInt('adcfg_at') ?? 0;
      String? raw = p.getString('adcfg');
      if (raw == null || DateTime.now().millisecondsSinceEpoch - at > 6 * 3600 * 1000) {
        final r = await http.get(Uri.parse(configUrl)).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) { raw = utf8.decode(r.bodyBytes); await p.setString('adcfg', raw); await p.setInt('adcfg_at', DateTime.now().millisecondsSinceEpoch); }
      }
      if (raw != null) { final j = jsonDecode(raw); if (j is Map) applyConfig(j); }
    } catch (e, st) { Health.log(e, st); }
  }
  static int dailyCap = 5; // rewarded ads per day (remote-configurable)
  static const rewardReeds = 5;
  static bool _init = false;

  static Future<void> init() async {
    if (_init) return;
    _init = true;
    try {
      await loadConfig();
      await _consent();
      if (!await ConsentInformation.instance.canRequestAds()) { _init = false; return; }
      await Stats.start();
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        maxAdContentRating: MaxAdContentRating.pg,
      ));
      await MobileAds.instance.initialize();
    } catch (e, st) { Health.log(e, st); }
  }

  /// Google's consent form (UMP). Shown only where it is required (for example the EEA and UK), otherwise it does nothing.
  static Future<void> _consent() async {
    final c = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try { await ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) { if (e != null) Health.log(e.message, StackTrace.current); }); } catch (e, st) { Health.log(e, st); }
        if (!c.isCompleted) c.complete();
      },
      (FormError e) { Health.log(e.message, StackTrace.current); if (!c.isCompleted) c.complete(); },
    );
    await c.future.timeout(const Duration(seconds: 25), onTimeout: () {});
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
  static Future<String> watchRewarded({bool reeds = true, void Function()? onReward}) async {
    await init();
    if (!rewardedOn) return 'none';
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
          ad.show(onUserEarnedReward: (_, __) async { earned = true; Stats.log('rewarded_earned'); if (reeds) Passport.addReeds(rewardReeds); onReward?.call(); await _count(); });
        },
        onAdFailedToLoad: (e) { if (!done.isCompleted) done.complete('none'); },
      ),
    );
    return done.future.timeout(const Duration(seconds: 45), onTimeout: () => 'none');
  }

  // ---- Interstitial: only after the user sent a papyrus, at most 1 per 30 min and 4 per day, never if ads are turned off. ----
  static InterstitialAd? _inter;
  static bool _interLoading = false;

  static Future<void> preloadInterstitial() async {
    if (_inter != null || _interLoading || interstitialId.isEmpty || !interstitialOn) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool('ads_off') ?? false) return;
    _interLoading = true;
    await init();
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: _req,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) { _inter = ad; _interLoading = false; },
        onAdFailedToLoad: (e) { _interLoading = false; },
      ),
    );
  }

  static Future<void> maybeInterstitialAfterSend() async {
    try {
      final ad = _inter;
      if (ad == null) return;
      final p = await SharedPreferences.getInstance();
      if (p.getBool('ads_off') ?? false) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = p.getInt('ia_last') ?? 0;
      final n = p.getString('ia_day') == _today() ? (p.getInt('ia_n') ?? 0) : 0;
      if (!interAllowed(nowMs: now, lastMs: last, shownToday: n, gapMin: interMinGapMin, dailyCap: interDailyCap)) return;
      await p.setInt('ia_last', now);
      await p.setString('ia_day', _today());
      await p.setInt('ia_n', n + 1);
      _inter = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) { a.dispose(); preloadInterstitial(); },
        onAdFailedToShowFullScreenContent: (a, e) { a.dispose(); },
      );
      Stats.log('interstitial_shown');
      await ad.show();
    } catch (e, st) { Health.log(e, st); }
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
    if (!Ads.nativeOn || !_ok || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 100,
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AdWidget(ad: _ad!)),
    );
  }
}
