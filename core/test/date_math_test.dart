import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('daysBetween', () {
    test('same calendar day is zero, regardless of time-of-day', () {
      expect(
        daysBetween(DateTime(2026, 8, 27, 1, 0), DateTime(2026, 8, 27, 23, 30)),
        0,
      );
    });

    test('counts whole calendar days forward', () {
      expect(daysBetween(DateTime(2026, 8, 27), DateTime(2026, 9, 3)), 7);
    });

    test('is negative when the second date is earlier', () {
      expect(daysBetween(DateTime(2026, 9, 3), DateTime(2026, 8, 27)), -7);
    });

    test('crosses a DST boundary without drifting', () {
      // US DST ends 2026-11-01; the civil day is 25h long.
      expect(daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 2);
    });
  });

  group('dayCountSince', () {
    test('start date is Day 1', () {
      expect(dayCountSince(DateTime(2026, 8, 27), DateTime(2026, 8, 27, 9)), 1);
    });

    test('next calendar day is Day 2', () {
      expect(
        dayCountSince(DateTime(2026, 8, 27, 23), DateTime(2026, 8, 28, 1)),
        2,
      );
    });
  });
}
