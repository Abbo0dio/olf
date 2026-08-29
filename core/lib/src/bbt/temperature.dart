/// Basal body temperature: units, conversion and a plausibility check.
///
/// Temperatures are stored **canonically in degrees Celsius** ([BbtEntry.tempCelsius]);
/// the unit here is a display-only preference. All conversion goes through this
/// file so rounding behaviour stays in one place.
library;

/// Which unit to show basal temperatures in. Storage is always Celsius.
enum TemperatureUnit { celsius, fahrenheit }

extension TemperatureUnitInfo on TemperatureUnit {
  /// `°C` / `°F`.
  String get symbol => switch (this) {
    TemperatureUnit.celsius => '°C',
    TemperatureUnit.fahrenheit => '°F',
  };

  /// Stable token for persisting the choice in `app_settings`.
  String get storageKey => name;

  static TemperatureUnit fromStorage(String? value) => switch (value) {
    'fahrenheit' => TemperatureUnit.fahrenheit,
    _ => TemperatureUnit.celsius,
  };
}

/// Plausible basal temperature range in °C. Outside this a reading is almost
/// certainly a typo (wrong unit, missing decimal point).
const double minPlausibleCelsius = 34.0;
const double maxPlausibleCelsius = 43.0;

double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;

double fahrenheitToCelsius(double f) => (f - 32) * 5 / 9;

/// Convert a stored Celsius value into [unit] for display.
double convertFromCelsius(double celsius, TemperatureUnit unit) =>
    switch (unit) {
      TemperatureUnit.celsius => celsius,
      TemperatureUnit.fahrenheit => celsiusToFahrenheit(celsius),
    };

/// Convert a value the user typed in [unit] back to Celsius for storage.
double toCelsius(double value, TemperatureUnit unit) => switch (unit) {
  TemperatureUnit.celsius => value,
  TemperatureUnit.fahrenheit => fahrenheitToCelsius(value),
};

/// Why a basal temperature was rejected. `null` from [validateCelsius] means it
/// is acceptable.
enum BbtError { tooLow, tooHigh }

extension BbtErrorMessage on BbtError {
  String describe() => switch (this) {
    BbtError.tooLow =>
      'That reading looks too low for a basal temperature — check the number.',
    BbtError.tooHigh =>
      'That reading looks too high for a basal temperature — check the number.',
  };
}

/// Thrown by [BbtRepository.setTemp] when a value fails [validateCelsius].
class BbtException implements Exception {
  const BbtException(this.error);

  final BbtError error;

  @override
  String toString() => 'BbtException: ${error.describe()}';
}

/// Check a Celsius reading against the plausible range. Returns the first
/// problem, or `null` when acceptable.
BbtError? validateCelsius(double celsius) {
  if (celsius < minPlausibleCelsius) return BbtError.tooLow;
  if (celsius > maxPlausibleCelsius) return BbtError.tooHigh;
  return null;
}
