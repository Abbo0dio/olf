import 'package:olf_core/olf_core.dart';

/// A stored Celsius reading formatted for display in [unit], e.g. `36.55 °C` or
/// `97.8 °F`. Celsius shows two decimals (basal charting needs the precision);
/// Fahrenheit shows one.
String formatTemp(double celsius, TemperatureUnit unit) {
  final value = convertFromCelsius(celsius, unit);
  final digits = unit == TemperatureUnit.celsius ? 2 : 1;
  return '${value.toStringAsFixed(digits)} ${unit.symbol}';
}

/// Just the number (no unit), for a compact chart axis label.
String formatTempValue(double celsius, TemperatureUnit unit) {
  final value = convertFromCelsius(celsius, unit);
  final digits = unit == TemperatureUnit.celsius ? 1 : 0;
  return value.toStringAsFixed(digits);
}
