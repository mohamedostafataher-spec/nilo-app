import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One calm, optional notification: a daily visit reminder, made on the phone (no server push, no tracking).
class Notify {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Future<void> init() async {
    if (_ready) return;
    await _p.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Asks Android for permission, then repeats once a day (about the time it was switched on).
  static Future<bool> enableDaily() async {
    try {
      await init();
      final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await a?.requestNotificationsPermission() ?? false;
      if (!ok) return false;
      await _p.periodicallyShow(
        1,
        'نيلو • Nilo',
        'زيارتك اليومية: قصب، القمر، وحكايات اليوم • Your daily visit: Reeds, the moon and today\'s stories',
        RepeatInterval.daily,
        const NotificationDetails(android: AndroidNotificationDetails('daily', 'Daily visit', channelDescription: 'One quiet reminder a day', importance: Importance.low, priority: Priority.low)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    try { await init(); await _p.cancel(1); } catch (_) {}
  }
}
