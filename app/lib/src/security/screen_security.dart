import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seam over the platform "treat this window as secure" capability (p2.4).
///
/// On Android `setSecure(true)` sets `WindowManager.LayoutParams.FLAG_SECURE`,
/// which keeps the window out of screenshots, screen recordings **and** the
/// Recents / task-switcher thumbnail. iOS exposes no equivalent OS control, so
/// the production implementation simply no-ops there — the app-switcher mask in
/// [PrivacyShield] (plus the native cover in `AppDelegate`) is the iOS
/// mitigation.
///
/// Same pattern as [ReminderScheduler] (p1.7) and [BiometricGateway] (p2.1): the
/// app depends on this interface, the production impl wraps a platform channel,
/// and tests inject a fake so CI never loads the channel.
abstract interface class ScreenSecurity {
  /// Turn the platform capture block on or off. Must never throw — a hardening
  /// call failing is not a reason to crash the app.
  Future<void> setSecure(bool secure);
}

/// Production [ScreenSecurity] over the `olf/screen_security` method channel,
/// handled natively in `MainActivity.kt`. On any platform without a handler
/// (iOS, desktop, the test binding) the call is swallowed.
class MethodChannelScreenSecurity implements ScreenSecurity {
  const MethodChannelScreenSecurity();

  static const MethodChannel _channel = MethodChannel('olf/screen_security');

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // No native handler on this platform — nothing to secure.
    } catch (_) {
      // Any other channel failure: log without detail and carry on.
      debugPrint('screen_security: setSecure($secure) failed');
    }
  }
}

/// The seam. Overridden with a fake in tests.
final screenSecurityProvider = Provider<ScreenSecurity>(
  (ref) => const MethodChannelScreenSecurity(),
);
