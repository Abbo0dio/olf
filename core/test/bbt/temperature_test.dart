import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('conversion', () {
    test('°C ↔ °F reference points', () {
      expect(celsiusToFahrenheit(0), closeTo(32, 1e-9));
      expect(celsiusToFahrenheit(37), closeTo(98.6, 1e-9));
      expect(fahrenheitToCelsius(98.6), closeTo(37, 1e-9));
      expect(fahrenheitToCelsius(32), closeTo(0, 1e-9));
    });

    test('round-trips through Fahrenheit', () {
      for (final c in [35.5, 36.4, 36.72, 37.0, 38.9]) {
        final back = toCelsius(
          convertFromCelsius(c, TemperatureUnit.fahrenheit),
          TemperatureUnit.fahrenheit,
        );
        expect(back, closeTo(c, 1e-9));
      }
    });

    test('celsius conversions are identities', () {
      expect(convertFromCelsius(36.6, TemperatureUnit.celsius), 36.6);
      expect(toCelsius(36.6, TemperatureUnit.celsius), 36.6);
    });
  });

  group('unit preference storage', () {
    test('fromStorage round-trips and defaults to celsius', () {
      for (final u in TemperatureUnit.values) {
        expect(TemperatureUnitInfo.fromStorage(u.storageKey), u);
      }
      expect(TemperatureUnitInfo.fromStorage(null), TemperatureUnit.celsius);
      expect(
        TemperatureUnitInfo.fromStorage('nonsense'),
        TemperatureUnit.celsius,
      );
    });

    test('symbols', () {
      expect(TemperatureUnit.celsius.symbol, '°C');
      expect(TemperatureUnit.fahrenheit.symbol, '°F');
    });
  });

  group('validateCelsius', () {
    test('accepts plausible basal temperatures', () {
      for (final c in [34.0, 35.8, 36.6, 37.4, 43.0]) {
        expect(validateCelsius(c), isNull, reason: '$c should be valid');
      }
    });

    test('rejects readings outside the plausible range', () {
      expect(validateCelsius(33.9), BbtError.tooLow);
      expect(validateCelsius(0), BbtError.tooLow);
      expect(validateCelsius(43.1), BbtError.tooHigh);
      expect(validateCelsius(98.6), BbtError.tooHigh); // °F typed as °C
    });

    test('every error has a non-empty message', () {
      for (final e in BbtError.values) {
        expect(e.describe(), isNotEmpty);
      }
    });
  });
}
