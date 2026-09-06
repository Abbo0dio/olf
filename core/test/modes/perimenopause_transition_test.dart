import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2020);
  var nextId = 1;

  setUp(() => nextId = 1);

  Period period(DateTime start) => Period(
    id: nextId++,
    startDate: start,
    endDate: start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// Periods built back-to-back from [gaps] (start-to-start day counts), the
  /// first one starting [first].
  List<Period> fromGaps(DateTime first, List<int> gaps) {
    final out = <Period>[period(first)];
    var d = first;
    for (final g in gaps) {
      d = d.add(Duration(days: g));
      out.add(period(d));
    }
    return out;
  }

  DateTime lastStart(List<Period> periods) =>
      periods.map((p) => p.startDate).reduce((a, b) => a.isAfter(b) ? a : b);

  test('returns null when nothing is logged', () {
    expect(
      derivePerimenopauseTransition(periods: const [], today: DateTime(2026)),
      isNull,
    );
  });

  test('a stable regular history reads as no clear change', () {
    final periods = fromGaps(DateTime(2025, 1, 1), const [
      28,
      29,
      27,
      28,
      30,
      28,
      27,
      29,
      28,
      28,
    ]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: lastStart(periods).add(const Duration(days: 10)),
    )!;

    expect(read.variabilityTrend, PerimenopauseVariabilityTrend.noClearChange);
    expect(read.stageHint, PerimenopauseStageHint.cyclesLookRegular);
    expect(read.longGapsBetweenCycles, isFalse);
    expect(read.twelveMonthsSinceLastPeriod, isFalse);
  });

  test('a widening cycle-length spread reads as becoming less regular', () {
    // Earlier half tight (27–29), later half wide (24–41) — no missed-entry
    // gaps (all <= 45 days), so this is spread, not skips.
    final periods = fromGaps(DateTime(2024, 6, 1), const [
      28,
      27,
      29,
      28,
      27,
      41,
      24,
      39,
      25,
      40,
    ]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: lastStart(periods).add(const Duration(days: 8)),
    )!;

    expect(read.earlierSpreadDays, lessThan(read.laterSpreadDays!));
    expect(
      read.variabilityTrend,
      PerimenopauseVariabilityTrend.becomingLessRegular,
    );
    expect(read.stageHint, PerimenopauseStageHint.cyclesBecomingLessRegular);
  });

  test('a recent long gap reads as long gaps between cycles', () {
    final periods = fromGaps(DateTime(2024, 1, 1), const [
      28,
      29,
      28,
      27,
      29,
      28,
      70,
      30,
      28,
      29,
    ]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: lastStart(periods).add(const Duration(days: 12)),
    )!;

    expect(read.recentSkipCount, greaterThanOrEqualTo(1));
    expect(read.longGapsBetweenCycles, isTrue);
    expect(read.stageHint, PerimenopauseStageHint.longGapsAppearing);
  });

  test('12+ months since the last period is surfaced factually', () {
    final periods = fromGaps(DateTime(2023, 1, 1), const [
      28,
      29,
      28,
      30,
      27,
      28,
      29,
      28,
    ]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: lastStart(periods).add(const Duration(days: 400)),
    )!;

    expect(read.daysSinceLastPeriod, 400);
    expect(read.twelveMonthsSinceLastPeriod, isTrue);
    expect(read.stageHint, PerimenopauseStageHint.twelveMonthsPlus);
    expect(read.longGapsBetweenCycles, isTrue);
  });

  test('thin history does not assert a trend', () {
    final periods = fromGaps(DateTime(2025, 1, 1), const [28, 29]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: DateTime(2025, 3, 10),
    )!;

    expect(read.variabilityTrend, PerimenopauseVariabilityTrend.notEnoughData);
    expect(read.trendIsMeaningful, isFalse);
    expect(read.stageHint, PerimenopauseStageHint.notEnoughData);
  });

  test('a future-dated last period clamps daysSinceLastPeriod to 0', () {
    final periods = fromGaps(DateTime(2026, 1, 1), const [
      28,
      28,
      28,
      28,
      28,
      28,
    ]);
    final read = derivePerimenopauseTransition(
      periods: periods,
      today: DateTime(2025, 12, 1),
    )!;
    expect(read.daysSinceLastPeriod, 0);
  });

  test('is deterministic regardless of input order', () {
    final periods = fromGaps(DateTime(2024, 3, 1), const [
      28,
      41,
      27,
      39,
      28,
      25,
      40,
      29,
      24,
      38,
    ]);
    final today = lastStart(periods).add(const Duration(days: 9));
    final a = derivePerimenopauseTransition(periods: periods, today: today);
    final b = derivePerimenopauseTransition(
      periods: periods.reversed.toList(),
      today: today,
    );
    expect(a, equals(b));
  });
}
