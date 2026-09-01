import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  // A fixed "now" so the recent-window cut-off is deterministic. The 30-day
  // window reaches back to 2026-05-16 (day-granular).
  final now = DateTime(2026, 6, 15, 12, 0);

  /// [count] timestamps at [hour] o'clock, all a few days before [now] so they
  /// sit inside the recent window.
  List<DateTime> at(int hour, int count) => [
    for (var i = 0; i < count; i++) DateTime(2026, 6, 10, hour, i),
  ];

  test('no timestamps → null', () {
    expect(learnPreferredHour(logTimestamps: const [], now: now), isNull);
  });

  test('below the minimum sample count → null', () {
    expect(
      learnPreferredHour(
        logTimestamps: at(21, kPreferredHourMinSamples - 1),
        now: now,
      ),
      isNull,
    );
  });

  test('exactly the minimum, tightly clustered → that hour', () {
    expect(
      learnPreferredHour(
        logTimestamps: at(21, kPreferredHourMinSamples),
        now: now,
      ),
      21,
    );
  });

  test('a clear single mode with a little symmetric noise → the mode', () {
    final samples = [...at(8, 10), ...at(7, 1), ...at(9, 1)];
    expect(learnPreferredHour(logTimestamps: samples, now: now), 8);
  });

  test('all identical → that hour', () {
    expect(learnPreferredHour(logTimestamps: at(6, 9), now: now), 6);
  });

  test(
    'two exactly-opposite clusters (08:00 / 20:00) → the arithmetic middle',
    () {
      final samples = [...at(8, 4), ...at(20, 4)];
      expect(learnPreferredHour(logTimestamps: samples, now: now), 14);
    },
  );

  test('samples spanning midnight average to 00:00, not noon', () {
    final samples = [...at(23, 3), ...at(0, 3), ...at(1, 3)];
    expect(learnPreferredHour(logTimestamps: samples, now: now), 0);
  });

  group('recent-window boundary', () {
    // 7 in-window samples; the 8th sits on / past the 30-day edge.
    final sevenRecent = at(10, 7);

    test('a sample exactly 30 days old is counted (→ not null)', () {
      final onEdge = [...sevenRecent, DateTime(2026, 5, 16, 10, 0)];
      expect(learnPreferredHour(logTimestamps: onEdge, now: now), 10);
    });

    test('a sample 31 days old is excluded (→ still below the minimum)', () {
      final tooOld = [...sevenRecent, DateTime(2026, 5, 15, 10, 0)];
      expect(learnPreferredHour(logTimestamps: tooOld, now: now), isNull);
    });
  });

  test('order of the timestamps does not matter', () {
    final a = [...at(9, 5), ...at(10, 5)];
    final b = a.reversed.toList();
    expect(
      learnPreferredHour(logTimestamps: a, now: now),
      learnPreferredHour(logTimestamps: b, now: now),
    );
  });
}
