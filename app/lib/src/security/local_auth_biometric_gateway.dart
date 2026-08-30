import 'package:local_auth/local_auth.dart';

import 'biometric_gateway.dart';

/// Production [BiometricGateway] — a thin wrapper over the `local_auth` plugin.
///
/// Not unit-tested (it is glue over a platform channel); the seam is exercised
/// through `FakeBiometricGateway`, exactly like `LocalNotificationReminder
/// Scheduler` (p1.7). Constructing it touches no channel; the first method call
/// does.
class LocalAuthBiometricGateway implements BiometricGateway {
  LocalAuthBiometricGateway([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      // `biometricOnly: true` below needs a real enrolled biometric, not just a
      // device passcode — check for one so the toggle is honest.
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      // PlatformException, MissingPluginException (unsupported platform), etc.
      return false;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Biometric strictly as the "it's me" shortcut. The app's own PIN is
        // the only knowledge factor — we don't let the *device* passcode stand
        // in for it (keeps the model clean for the p2.2 decoy PIN).
        biometricOnly: true,
        // Retry instead of erroring if the OS suspends the prompt on a
        // backgrounding.
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } catch (_) {
      return BiometricAuthResult.unavailable;
    }
  }
}
