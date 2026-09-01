import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  // A candidate carries seconds/millis so we can check they are zeroed on shift.
  DateTime at(int hour, int minute) =>
      DateTime(2026, 3, 10, hour, minute, 42, 7);

  group('applyQuietHours — disabled', () {
    test('a disabled window is a pass-through', () {
      const window = QuietHours(
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        enabled: false,
      );
      final candidate = at(3, 0);
      expect(applyQuietHours(candidate, window), same(candidate));
    });

    test('kDefaultQuietHours is disabled', () {
      expect(kDefaultQuietHours.enabled, isFalse);
      final candidate = at(2, 30);
      expect(applyQuietHours(candidate, kDefaultQuietHours), same(candidate));
    });

    test('a zero-width enabled window holds nothing', () {
      const window = QuietHours(
        startHour: 9,
        startMinute: 0,
        endHour: 9,
        endMinute: 0,
        enabled: true,
      );
      final candidate = at(9, 0);
      expect(applyQuietHours(candidate, window), same(candidate));
    });
  });

  group('applyQuietHours — non-wrapping window (13:00–14:00)', () {
    const window = QuietHours(
      startHour: 13,
      startMinute: 0,
      endHour: 14,
      endMinute: 0,
      enabled: true,
    );

    test('before the window: unchanged', () {
      final c = at(12, 59);
      expect(applyQuietHours(c, window), same(c));
    });

    test('exactly at the start: inside, shifts to the end', () {
      expect(applyQuietHours(at(13, 0), window), DateTime(2026, 3, 10, 14, 0));
    });

    test('inside the window: shifts to the end', () {
      expect(applyQuietHours(at(13, 30), window), DateTime(2026, 3, 10, 14, 0));
    });

    test('exactly at the end: outside, unchanged', () {
      final c = at(14, 0);
      expect(applyQuietHours(c, window), same(c));
    });

    test('after the window: unchanged', () {
      final c = at(14, 1);
      expect(applyQuietHours(c, window), same(c));
    });

    test('the shifted instant has seconds and millis zeroed', () {
      final shifted = applyQuietHours(at(13, 30), window);
      expect(shifted.second, 0);
      expect(shifted.millisecond, 0);
    });
  });

  group('applyQuietHours — midnight-wrap window (22:00–07:00)', () {
    const window = QuietHours(
      startHour: 22,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      enabled: true,
    );

    test('exactly at the start (22:00): inside, shifts to next-day end', () {
      expect(applyQuietHours(at(22, 0), window), DateTime(2026, 3, 11, 7, 0));
    });

    test('late evening (23:30): shifts to 07:00 the next day', () {
      expect(applyQuietHours(at(23, 30), window), DateTime(2026, 3, 11, 7, 0));
    });

    test('after midnight (03:00): shifts to 07:00 the same day', () {
      expect(applyQuietHours(at(3, 0), window), DateTime(2026, 3, 10, 7, 0));
    });

    test('one minute before the end (06:59): shifts to 07:00 the same day', () {
      expect(applyQuietHours(at(6, 59), window), DateTime(2026, 3, 10, 7, 0));
    });

    test('exactly at the end (07:00): outside, unchanged', () {
      final c = at(7, 0);
      expect(applyQuietHours(c, window), same(c));
    });

    test('midday (12:00): outside, unchanged', () {
      final c = at(12, 0);
      expect(applyQuietHours(c, window), same(c));
    });

    test('an evening shift that crosses a month boundary', () {
      final endOfMonth = DateTime(2026, 3, 31, 23, 0);
      expect(applyQuietHours(endOfMonth, window), DateTime(2026, 4, 1, 7, 0));
    });
  });

  group('QuietHours value semantics', () {
    test('== / hashCode by field', () {
      const a = QuietHours(
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        enabled: true,
      );
      const b = QuietHours(
        startHour: 22,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        enabled: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.copyWith(enabled: false), isNot(equals(a)));
    });

    test('copyWith replaces only the named fields', () {
      final shifted = kDefaultQuietHours.copyWith(enabled: true, endHour: 8);
      expect(shifted.enabled, isTrue);
      expect(shifted.endHour, 8);
      expect(shifted.startHour, kDefaultQuietHours.startHour);
    });
  });
}
