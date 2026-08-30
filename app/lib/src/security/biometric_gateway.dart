/// Biometric unlock seam (p2.1).
///
/// Face ID / Touch ID / Android biometric prompt, wrapped behind an interface
/// so the lock screen and settings can be widget-tested without a platform
/// channel — the same pattern as `ReminderScheduler` (p1.7) and
/// `BackupFileGateway` (p1.10). The app talks to this; the production
/// implementation ([LocalAuthBiometricGateway]) wraps the `local_auth` plugin;
/// tests pass a fake.
///
/// **Scope.** Biometric unlock is a convenience shortcut *past* the PIN, never a
/// lock on its own: it is only offered while a PIN is set, and the PIN entry
/// stays available as the fallback. It does not wrap the database key.
library;

/// Outcome of a biometric prompt.
enum BiometricAuthResult {
  /// The user passed the biometric check.
  success,

  /// Hardware and enrolment are fine but this attempt did not succeed — a wrong
  /// finger/face, or the user dismissed the prompt. The caller stays on the PIN
  /// screen without nagging.
  failed,

  /// No usable biometric right now: no hardware, nothing enrolled, the OS is in
  /// biometric lockout, or the platform is unsupported. The caller should hide
  /// the biometric affordance and fall back to the PIN.
  unavailable,
}

/// Contract over the platform biometric API.
abstract interface class BiometricGateway {
  /// Whether this device has biometric hardware with something enrolled and the
  /// OS can show a prompt. `false` means never offer biometric unlock.
  Future<bool> canAuthenticate();

  /// Show the biometric prompt, using [reason] where the platform puts an
  /// explanatory string (iOS `localizedReason`, Android subtitle).
  Future<BiometricAuthResult> authenticate({required String reason});
}
