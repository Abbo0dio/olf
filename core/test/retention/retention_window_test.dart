import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('RetentionWindow.cutoff', () {
    final now = DateTime(2026, 8, 15, 14, 30);

    test('off has no cutoff', () {
      expect(RetentionWindow.off.cutoff(now), isNull);
    });

    test('months6 is six calendar months back', () {
      expect(RetentionWindow.months6.cutoff(now), DateTime(2026, 2, 15));
    });

    test('year1 / years2 / years3 are whole calendar years back', () {
      expect(RetentionWindow.year1.cutoff(now), DateTime(2025, 8, 15));
      expect(RetentionWindow.years2.cutoff(now), DateTime(2024, 8, 15));
      expect(RetentionWindow.years3.cutoff(now), DateTime(2023, 8, 15));
    });

    test('cutoff normalises an impossible day rather than throwing', () {
      // 6 months before 31 Aug is "31 Feb" → DateTime rolls it into March.
      final c = RetentionWindow.months6.cutoff(DateTime(2026, 8, 31));
      expect(c, DateTime(2026, 3, 3));
    });

    test('cutoff drops the time-of-day (fresh local midnight)', () {
      final c = RetentionWindow.year1.cutoff(now)!;
      expect(c.hour, 0);
      expect(c.minute, 0);
      expect(c.isUtc, isFalse);
    });
  });

  group('RetentionWindow storage', () {
    test('storageToken round-trips through fromStorage for every value', () {
      for (final w in RetentionWindow.values) {
        expect(RetentionWindow.fromStorage(w.storageToken), w);
      }
    });

    test('null / unknown token falls back to off', () {
      expect(RetentionWindow.fromStorage(null), RetentionWindow.off);
      expect(RetentionWindow.fromStorage(''), RetentionWindow.off);
      expect(RetentionWindow.fromStorage('forever'), RetentionWindow.off);
      expect(RetentionWindow.fromStorage('6m'), RetentionWindow.off);
    });

    test('every value has a non-empty label', () {
      for (final w in RetentionWindow.values) {
        expect(w.label, isNotEmpty);
      }
      expect(
        RetentionWindow.values.map((w) => w.label).toSet(),
        hasLength(RetentionWindow.values.length),
        reason: 'labels must be distinct',
      );
    });
  });
}
