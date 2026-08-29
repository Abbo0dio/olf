import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime(2026, 8, 29);

  test('every BirthControlMethod has a non-empty label', () {
    for (final m in BirthControlMethod.values) {
      expect(m.label, isNotEmpty);
    }
  });

  group('validateBirthControlDates', () {
    test('accepts a start today with no end', () {
      expect(validateBirthControlDates(startedOn: today, today: today), isNull);
    });

    test('accepts a past start', () {
      expect(
        validateBirthControlDates(
          startedOn: DateTime(2025, 1, 1),
          today: today,
        ),
        isNull,
      );
    });

    test('rejects a start in the future', () {
      expect(
        validateBirthControlDates(
          startedOn: DateTime(2026, 8, 30),
          today: today,
        ),
        BirthControlError.startInFuture,
      );
    });

    test('compares start by calendar day, not time', () {
      expect(
        validateBirthControlDates(
          startedOn: DateTime(2026, 8, 29, 23, 59),
          today: DateTime(2026, 8, 29, 0, 1),
        ),
        isNull,
      );
    });

    test('rejects an end before the start', () {
      expect(
        validateBirthControlDates(
          startedOn: DateTime(2026, 8, 10),
          endedOn: DateTime(2026, 8, 9),
          today: today,
        ),
        BirthControlError.endBeforeStart,
      );
    });

    test('accepts an end equal to the start', () {
      expect(
        validateBirthControlDates(
          startedOn: DateTime(2026, 8, 10),
          endedOn: DateTime(2026, 8, 10),
          today: today,
        ),
        isNull,
      );
    });
  });

  test('BirthControlError.describe is a non-empty sentence', () {
    for (final e in BirthControlError.values) {
      expect(e.describe(), isNotEmpty);
    }
  });
}
