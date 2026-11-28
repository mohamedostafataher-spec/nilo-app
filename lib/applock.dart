import 'i18n.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart';
import 'world.dart';

/// Optional lock: fingerprint / face / phone screen lock. Off by default.
/// The check is done by Android itself. Nilo never sees the fingerprint.
/// The phone PIN or pattern also unlocks it (so a wet finger does not lock you out).
class AppLock {
  static final _auth = LocalAuthentication();
  static bool get enabled => Passport.flag('app_lock', false);
  static bool busy = false;

  static Future<bool> available() async {
    try { return await _auth.isDeviceSupported(); } catch (_) { return false; }
  }

  static Future<bool> authenticate() async {
    busy = true;
    try {
      return await _auth.authenticate(
        localizedReason: L('Unlock Nilo'),
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } catch (_) {
      return false;
    } finally {
      busy = false;
    }
  }

  /// Turn on only after the phone confirmed it can check you. Turning off also asks once.
  static Future<String?> setEnabled(bool on) async {
    if (on && !await available()) return L('This phone has no fingerprint or screen lock set up. Set one in the phone settings first.');
    if (!await authenticate()) return L('Not confirmed, so the lock stays as it was.');
    Passport.setFlag('app_lock', on);
    return null;
  }
}

/// Wraps the whole app. Locks when the app goes to the background, asks again when it comes back.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool locked = AppLock.enabled;
  DateTime? left;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (locked) WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!AppLock.enabled || AppLock.busy) return;
    if (s == AppLifecycleState.paused) left = DateTime.now();
    if (s == AppLifecycleState.resumed && left != null) {
      // A short trip (under 10 s) does not lock, so answering a call or a permission dialog is smooth.
      if (DateTime.now().difference(left!).inSeconds >= 10) { setState(() => locked = true); _ask(); }
      left = null;
    }
  }

  Future<void> _ask() async {
    if (AppLock.busy) return;
    final ok = await AppLock.authenticate();
    if (ok && mounted) setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!locked || !AppLock.enabled) return widget.child;
    return Directionality(
      textDirection: Ui.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: kBg,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fingerprint, size: 72, color: kGreen),
          const SizedBox(height: 14),
          Text(L('Nilo is locked'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          FilledButton(onPressed: _ask, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: Text(L('Unlock')))),
        ])),
      ),
    );
  }
}
