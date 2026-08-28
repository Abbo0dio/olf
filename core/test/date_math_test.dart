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

  group('isWithinRange', () {
    test('inclusive on both ends', () {
      final start = DateTime(2026, 8, 10);
      final end = DateTime(2026, 8, 15);
      expect(isWithinRange(DateTime(2026, 8, 10), start, end), isTrue);
      expect(isWithinRange(DateTime(2026, 8, 13, 23), start, end), isTrue);
      expect(isWithinRange(DateTime(2026, 8, 15), start, end), isTrue);
      expect(isWithinRange(DateTime(2026, 8, 9), start, end), isFalse);
      expect(isWithinRange(DateTime(2026, 8, 16), start, end), isFalse);
    });

    test('a null end is an open range', () {
      final start = DateTime(2026, 8, 10);
      expect(isWithinRange(DateTime(2026, 8, 9), start, null), isFalse);
      expect(isWithinRange(DateTime(2030, 1, 1), start, null), isTrue);
    });
  });

  group('month helpers', () {
    test('firstOfMonth / lastOfMonth / daysInMonth', () {
      final mid = DateTime(2026, 2, 17, 8, 30);
      expect(firstOfMonth(mid), DateTime(2026, 2, 1));
      expect(lastOfMonth(mid), DateTime(2026, 2, 28));
      expect(daysInMonth(mid), 28);
      expect(daysInMonth(DateTime(2024, 2, 1)), 29); // leap year
      expect(daysInMonth(DateTime(2026, 12, 1)), 31);
    });

    test('addMonths wraps years and never lands on an impossible date', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 1));
      expect(addMonths(DateTime(2026, 12, 10), 1), DateTime(2027, 1, 1));
    });
  });
}
