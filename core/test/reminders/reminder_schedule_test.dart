import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  ReminderSchedule at(int hour, int minute, {bool enabled = true}) =>
      ReminderSchedule(
        kind: ReminderKind.medication,
        hour: hour,
        minute: minute,
        enabled: enabled,
      );

  group('validateReminderTime', () {
    test('accepts the edges of the day', () {
      expect(validateReminderTime(0, 0), isNull);
      expect(validateReminderTime(23, 59), isNull);
    });

    test('rejects an out-of-range hour', () {
      expect(validateReminderTime(-1, 0), ReminderError.hourOutOfRange);
      expect(validateReminderTime(24, 0), ReminderError.hourOutOfRange);
    });

    test('rejects an out-of-range minute', () {
      expect(validateReminderTime(9, -1), ReminderError.minuteOutOfRange);
      expect(validateReminderTime(9, 60), ReminderError.minuteOutOfRange);
    });

    test('checks the hour before the minute', () {
      expect(validateReminderTime(99, 99), ReminderError.hourOutOfRange);
    });
  });

  group('ReminderSchedule value semantics', () {
    test('equality is by field', () {
      expect(at(9, 0), equals(at(9, 0)));
      expect(at(9, 0), isNot(equals(at(9, 1))));
      expect(at(9, 0, enabled: true), isNot(equals(at(9, 0, enabled: false))));
    });

    test('copyWith replaces only the named fields', () {
      final base = at(9, 0, enabled: false);
      expect(base.copyWith(enabled: true), at(9, 0, enabled: true));
      expect(base.copyWith(hour: 21, minute: 30), at(21, 30, enabled: false));
      expect(base.copyWith().kind, ReminderKind.medication);
    });

    test('toString shows a zero-padded time and no health text', () {
      final s = at(8, 5).toString();
      expect(s, contains('08:05'));
      expect(s.toLowerCase(), isNot(contains('medication name')));
    });
  });

  group('nextOccurrence', () {
    test('returns today when the time is still ahead', () {
      final from = DateTime(2026, 8, 29, 7, 30);
      expect(nextOccurrence(at(9, 0), from: from), DateTime(2026, 8, 29, 9, 0));
    });

    test('rolls to tomorrow when the time has passed', () {
      final from = DateTime(2026, 8, 29, 10, 15);
      expect(nextOccurrence(at(9, 0), from: from), DateTime(2026, 8, 30, 9, 0));
    });

    test('an exact match counts as now (fire today)', () {
      final from = DateTime(2026, 8, 29, 9, 0);
      expect(nextOccurrence(at(9, 0), from: from), DateTime(2026, 8, 29, 9, 0));
    });

    test('crosses a month boundary correctly', () {
      final from = DateTime(2026, 8, 31, 23, 59);
      expect(nextOccurrence(at(6, 0), from: from), DateTime(2026, 9, 1, 6, 0));
    });

    test('ignores enabled — it is the caller\'s call', () {
      final from = DateTime(2026, 8, 29, 7, 0);
      expect(
        nextOccurrence(at(9, 0, enabled: false), from: from),
        DateTime(2026, 8, 29, 9, 0),
      );
    });
  });
}
