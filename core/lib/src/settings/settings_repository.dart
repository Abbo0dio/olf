/// Well-known keys for the [SettingsRepository] key/value store.
abstract final class SettingKeys {
  /// Preferred display unit for basal temperatures — a [TemperatureUnit] name.
  static const String temperatureUnit = 'temperature_unit';

  /// `'true'` once the first-run privacy explainer has been acknowledged (p1.8).
  /// Absent / anything else means it still needs to be shown.
  static const String onboardingComplete = 'onboarding_complete';

  /// Manual light/dark override (p1.9): `'system'` (default), `'light'`, `'dark'`.
  static const String themeMode = 'theme_mode';

  /// The user's pronouns for copy (p1.9) — a [Pronouns] name. Absent resolves to
  /// they/them so default copy is correct with nothing set.
  static const String pronouns = 'pronouns';

  /// `'true'` when the user has opted in to unlocking with device biometrics
  /// (p2.1). Only meaningful while a PIN is set — biometric unlock is a shortcut
  /// past the PIN, never a lock on its own. Absent / anything else means off.
  static const String biometricUnlock = 'biometric_unlock';

  /// Scheduled auto-deletion window (p2.3) — a `RetentionWindow` name. Absent /
  /// anything unrecognised means `off` (keep everything). Dated entries older
  /// than the window are purged on launch, on change, and before a new backup.
  static const String retentionWindow = 'retention_window';

  /// `'true'` if the user has opted in to on-device usage analytics (p2.5).
  /// Absent / anything else means off — the default. olf collects nothing while
  /// this is off; the switch only gates a possible future on-device metric.
  static const String analyticsOptIn = 'analytics_opt_in';

  /// `'true'` if the user has opted in to sharing data with third parties
  /// (p2.5). Absent / anything else means off — the default. olf shares nothing
  /// regardless of this today; it exists so any future sharing is opt-in.
  static const String dataSharingOptIn = 'data_sharing_opt_in';

  /// The app-wide quiet-hours window (p4.4) — an opaque `QuietHours` encoding
  /// owned by the app layer (`quiet_hours_providers.dart`). Absent means the
  /// default: disabled, so nothing is held.
  static const String quietHours = 'quiet_hours';

  /// `'true'` once the user has permanently turned off subscription / upsell
  /// prompting (p4.5). Absent / `'false'` / anything else means prompts are
  /// allowed — the default. Read only through [subscriptionPromptsAllowed] so
  /// the "absent = allowed" rule lives in one place. This is a **hard gate**:
  /// every paid-tier prompt added in Phase 10+ must honour it — see
  /// `docs/monetization-principles.md`.
  static const String suppressSubscriptionPrompts =
      'suppress_subscription_prompts';
}

/// Whether subscription / upsell / paid-tier prompts may be shown, given the
/// raw [SettingKeys.suppressSubscriptionPrompts] value.
///
/// Only the exact string `'true'` suppresses. Absent, `'false'`, or any
/// unrecognised / malformed value ⇒ `true` (prompts allowed) — a storage glitch
/// must never silently hide a paid feature the user never chose to turn off,
/// and this matches the "absent = allowed" default.
bool subscriptionPromptsAllowed(String? rawSetting) => rawSetting != 'true';

/// A tiny persistent key/value store for user preferences (`app_settings`).
///
/// Values are opaque strings; each caller owns its own encoding. Introduced for
/// p1.6's °C/°F choice; p1.8 / p1.9 reuse it.
abstract interface class SettingsRepository {
  /// The current value for [key], or `null` if unset.
  Future<String?> get(String key);

  /// The value for [key] as a stream that re-emits on every write (starting with
  /// the current value, or `null`).
  Stream<String?> watch(String key);

  /// Store [value] under [key], replacing any existing value.
  Future<void> set(String key, String value);

  /// Remove [key]. A no-op if it is unset.
  Future<void> remove(String key);
}
