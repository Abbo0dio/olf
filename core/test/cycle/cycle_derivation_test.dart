import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  /// A stored period from [start] to [end] (calendar dates); ids/timestamps are
  /// filler — cycle derivation only looks at the two dates.
  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end,
    createdAt: epoch,
    updatedAt: epoch,
  );

  setUp(() => nextId = 1);

  group('deriveCycles', () {
    test('no periods yields no cycles', () {
      expect(deriveCycles(const []), isEmpty);
    });

    test('one closed period is a single current cycle with no length', () {
      final cycles = deriveCycles([
        period(DateTime(2026, 8, 3), DateTime(2026, 8, 7)),
      ]);

      expect(cycles, hasLength(1));
      final only = cycles.single;
      expect(only.isCurrent, isTrue);
      expect(only.lengthInDays, isNull);
      expect(only.periodLengthInDays, 5); // 3rd–7th inclusive
      expect(only.isLikelyGap, isFalse);
    });

    test('one ongoing period has no period length either', () {
      final cycles = deriveCycles([period(DateTime(2026, 8, 3))]);
      expect(cycles.single.periodLengthInDays, isNull);
      expect(cycles.single.isCurrent, isTrue);
    });

    test('consecutive periods pair start-to-start, newest cycle first', () {
      final cycles = deriveCycles([
        period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
        period(
          DateTime(2026, 6, 29),
          DateTime(2026, 7, 3),
        ), // 28 days after 1 Jun
        period(
          DateTime(2026, 7, 30),
          DateTime(2026, 8, 2),
        ), // 31 days after 29 Jun
      ]);

      expect(cycles.map((c) => c.periodStart), [
        DateTime(2026, 7, 30),
        DateTime(2026, 6, 29),
        DateTime(2026, 6, 1),
      ]);
      expect(cycles.map((c) => c.lengthInDays), [null, 31, 28]);
      expect(cycles.first.isCurrent, isTrue);
      expect(cycles.where((c) => c.isCurrent), hasLength(1));
    });

    test('input order does not matter', () {
      final ordered = deriveCycles([
        period(DateTime(2026, 6, 1)),
        period(DateTime(2026, 6, 29)),
        period(DateTime(2026, 7, 30)),
      ]);
      final shuffled = deriveCycles([
        period(DateTime(2026, 7, 30)),
        period(DateTime(2026, 6, 1)),
        period(DateTime(2026, 6, 29)),
      ]);
      expect(shuffled, ordered);
    });

    test('an over-long interval is flagged as a likely unlogged gap', () {
      final cycles = deriveCycles([
        period(DateTime(2026, 3, 1)),
        period(DateTime(2026, 5, 1)), // 61 days later
        period(DateTime(2026, 5, 29)), // 28 days later
      ]);

      final byStart = {for (final c in cycles) c.periodStart: c};
      expect(byStart[DateTime(2026, 3, 1)]!.lengthInDays, 61);
      expect(byStart[DateTime(2026, 3, 1)]!.isLikelyGap, isTrue);
      expect(byStart[DateTime(2026, 5, 1)]!.isLikelyGap, isFalse);
    });

    test('45 days is not a gap, 46 is', () {
      Cycle first(List<Period> ps) => deriveCycles(ps).last;
      expect(
        first([
          period(DateTime(2026, 1, 1)),
          period(DateTime(2026, 2, 15)), // +45
        ]).isLikelyGap,
        isFalse,
      );
      expect(
        first([
          period(DateTime(2026, 1, 1)),
          period(DateTime(2026, 2, 16)), // +46
        ]).isLikelyGap,
        isTrue,
      );
    });

    test('time-of-day on the stored dates is ignored', () {
      final cycles = deriveCycles([
        period(DateTime(2026, 6, 1, 23, 30), DateTime(2026, 6, 5, 6)),
        period(DateTime(2026, 6, 29, 1), DateTime(2026, 7, 3, 22)),
      ]);
      expect(cycles.last.lengthInDays, 28);
      expect(cycles.last.periodLengthInDays, 5);
      expect(cycles.last.periodStart, DateTime(2026, 6, 1));
    });
  });

  group('CycleStats.from', () {
    /// Build a run of periods, oldest first: the first starts 1 Jan 2026, each
    /// subsequent one starts [gaps] days after the previous. Every period is a
    /// 4-day bleed. Only the spacing matters.
    List<Period> runOf(List<int> gaps) {
      var day = DateTime(2026, 1, 1);
      final out = <Period>[period(day, day.add(const Duration(days: 3)))];
      for (final g in gaps) {
        day = day.add(Duration(days: g));
        out.add(period(day, day.add(const Duration(days: 3))));
      }
      return out;
    }

    test('no cycles → empty stats, not a 28-day guess', () {
      const stats = CycleStats.empty;
      expect(CycleStats.from(const []), stats);
      expect(stats.typicalCycleLength, isNull);
      expect(stats.regularity, CycleRegularity.notEnoughData);
    });

    test('a single logged period → no length figures, no crash', () {
      final stats = CycleStats.from(
        deriveCycles([period(DateTime(2026, 8, 1), DateTime(2026, 8, 5))]),
      );
      expect(stats.completedCycleCount, 0);
      expect(stats.typicalCycleLength, isNull);
      expect(stats.shortestCycleLength, isNull);
      expect(stats.longestCycleLength, isNull);
      expect(stats.typicalPeriodLength, 5); // the one recorded period
      expect(stats.regularity, CycleRegularity.notEnoughData);
      expect(stats.hasLikelyGap, isFalse);
    });

    test('one completed cycle → length known but regularity still unknown', () {
      final stats = CycleStats.from(deriveCycles(runOf([29])));
      expect(stats.completedCycleCount, 1);
      expect(stats.typicalCycleLength, 29);
      expect(stats.shortestCycleLength, 29);
      expect(stats.longestCycleLength, 29);
      expect(stats.regularity, CycleRegularity.notEnoughData);
    });

    test('tight spread → regular; median is the typical length', () {
      final stats = CycleStats.from(deriveCycles(runOf([28, 30, 28, 29])));
      expect(stats.completedCycleCount, 4);
      expect(stats.shortestCycleLength, 28);
      expect(stats.longestCycleLength, 30);
      expect(
        stats.typicalCycleLength,
        29,
      ); // median of [28,28,29,30] → 28.5 → 29
      expect(stats.regularity, CycleRegularity.regular);
    });

    test('spread of 9 → mostly regular; 10 → irregular', () {
      expect(
        CycleStats.from(deriveCycles(runOf([25, 34, 30]))).regularity,
        CycleRegularity.mostlyRegular, // 34 − 25 = 9
      );
      expect(
        CycleStats.from(deriveCycles(runOf([25, 35, 30]))).regularity,
        CycleRegularity.irregular, // 35 − 25 = 10
      );
    });

    test('odd-count median picks the middle value', () {
      final stats = CycleStats.from(deriveCycles(runOf([27, 31, 29])));
      expect(stats.typicalCycleLength, 29);
    });

    test('a likely-gap cycle is flagged but left out of the figures', () {
      // 28, then a 70-day gap, then 29.
      final stats = CycleStats.from(deriveCycles(runOf([28, 70, 29])));
      expect(stats.hasLikelyGap, isTrue);
      expect(stats.completedCycleCount, 2); // only 28 and 29 counted
      expect(stats.shortestCycleLength, 28);
      expect(stats.longestCycleLength, 29);
      expect(stats.typicalCycleLength, 29); // median of [28,29] → 28.5 → 29
      expect(stats.regularity, CycleRegularity.regular);
    });

    test('history all gaps → figures null but the gap is surfaced', () {
      final stats = CycleStats.from(deriveCycles(runOf([80, 90])));
      expect(stats.hasLikelyGap, isTrue);
      expect(stats.completedCycleCount, 0);
      expect(stats.typicalCycleLength, isNull);
      expect(stats.regularity, CycleRegularity.notEnoughData);
    });

    test('only the most recent 12 completed cycles feed the figures', () {
      // One wild 40-day cycle, then 14 steady 28-day cycles.
      final gaps = [40, for (var i = 0; i < 14; i++) 28];
      final stats = CycleStats.from(deriveCycles(runOf(gaps)));
      expect(stats.completedCycleCount, CycleStats.recentWindow);
      expect(stats.shortestCycleLength, 28);
      expect(stats.longestCycleLength, 28); // the 40 fell outside the window
      expect(stats.regularity, CycleRegularity.regular);
    });

    test('typical period length is the median of recorded bleeds', () {
      final periods = [
        period(DateTime(2026, 1, 1), DateTime(2026, 1, 4)), // 4
        period(DateTime(2026, 1, 29), DateTime(2026, 2, 2)), // 5
        period(DateTime(2026, 2, 26), DateTime(2026, 3, 3)), // 6
        period(DateTime(2026, 3, 26)), // ongoing — no length
      ];
      expect(CycleStats.from(deriveCycles(periods)).typicalPeriodLength, 5);
    });
  });

  test('editing a period changes the derived history', () {
    final before = CycleStats.from(
      deriveCycles([
        period(DateTime(2026, 4, 1)),
        period(DateTime(2026, 5, 1)),
      ]),
    );
    expect(before.typicalCycleLength, 30); // 1 Apr → 1 May

    // "Correct" the May period to the 5th.
    final after = CycleStats.from(
      deriveCycles([
        period(DateTime(2026, 4, 1)),
        period(DateTime(2026, 5, 5)),
      ]),
    );
    expect(after.typicalCycleLength, 34);
  });
}
