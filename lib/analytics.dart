import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'health.dart';

/// Firebase Analytics, switched on ONLY after Google's consent flow says ads/analytics may run (see Ads.init).
/// Collection is off in the manifest, so nothing is sent before that. Only event names and counts, no message text.
class Stats {
  static bool _on = false;

  static Future<void> start() async {
    if (_on) return;
    try {
      await Firebase.initializeApp();
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      _on = true;
    } catch (e, st) { Health.log(e, st); }
  }

  static void log(String name, [Map<String, Object>? params]) {
    if (!_on) return;
    try { FirebaseAnalytics.instance.logEvent(name: name, parameters: params); } catch (e, st) { Health.log(e, st); }
  }
}
