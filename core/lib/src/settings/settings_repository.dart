/// Well-known keys for the [SettingsRepository] key/value store.
abstract final class SettingKeys {
  /// Preferred display unit for basal temperatures — a [TemperatureUnit] name.
  static const String temperatureUnit = 'temperature_unit';
}

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
