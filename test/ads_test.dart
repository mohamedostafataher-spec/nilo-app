import 'package:flutter_test/flutter_test.dart';
import 'package:nilo_app/ads.dart';

void main() {
  test('interstitial: first one is allowed', () {
    expect(Ads.interAllowed(nowMs: 1000000000, lastMs: 0, shownToday: 0, gapMin: 30, dailyCap: 4), isTrue);
  });
  test('interstitial: blocked inside the 30 minute gap, allowed after', () {
    const base = 1000000000;
    expect(Ads.interAllowed(nowMs: base + 29 * 60000, lastMs: base, shownToday: 1, gapMin: 30, dailyCap: 4), isFalse);
    expect(Ads.interAllowed(nowMs: base + 30 * 60000, lastMs: base, shownToday: 1, gapMin: 30, dailyCap: 4), isTrue);
  });
  test('interstitial: daily cap of 4 holds', () {
    expect(Ads.interAllowed(nowMs: 9000000000, lastMs: 0, shownToday: 4, gapMin: 30, dailyCap: 4), isFalse);
  });
  test('remote config is clamped and bad values fall back to defaults', () {
    Ads.applyConfig({'inter_gap_min': 1, 'inter_daily': 999, 'rewarded_daily': 'x', 'interstitial': false});
    expect(Ads.interMinGapMin, 5);
    expect(Ads.interDailyCap, 20);
    expect(Ads.dailyCap, 5);
    expect(Ads.interstitialOn, isFalse);
    Ads.applyConfig({});
    expect(Ads.interMinGapMin, 30);
    expect(Ads.interDailyCap, 4);
    expect(Ads.interstitialOn, isTrue);
  });
}
