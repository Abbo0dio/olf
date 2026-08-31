import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// Build a scored point with a chosen absolute error and range, by placing the
/// actual start [absError] days after the predicted midpoint.
BacktestPoint _point({
  required int absError,
  int rangeRadius = 3,
  int? recentCycleLength,
  int? ovulationAbsError,
}) {
  final asOf = DateTime(2024, 6, 1);
  final predictedMid = DateTime(2024, 6, 28);
  final actualNextStart = predictedMid.add(Duration(days: absError));
  final range = DateRange(
    predictedMid.subtract(Duration(days: rangeRadius)),
    predictedMid.add(Duration(days: rangeRadius)),
  );
  final ovulation = predictedMid.subtract(const Duration(days: 14));
  final fertileStart = ovulation.subtract(const Duration(days: 5));
  return BacktestPoint(
    asOf: asOf,
    completedCycles: 3,
    mostRecentCycleLength: recentCycleLength,
    actualNextStart: actualNextStart,
    actualOvulation: ovulationAbsError == null
        ? null
        : ovulation.add(Duration(days: ovulationAbsError)),
    prediction: CyclePrediction(
      nextPeriod: range,
      nextPeriodExpected: predictedMid,
      fertileWindow: DateRange(
        fertileStart,
        ovulation.add(const Duration(days: 1)),
      ),
      confidence: PredictionConfidence.medium,
      basedOnCycles: 3,
      status: PredictionStatus.upcoming,
      daysPastExpected: null,
    ),
  );
}

void main() {
  test('mean / median absolute error on a hand-checked set', () {
    final run = BacktestRun(
      label: 't',
      points: [
        _point(absError: 0),
        _point(absError: 2),
        _point(absError: 2),
        _point(absError: 10),
      ],
    );
    final m = BacktestMetrics.of(run);
    expect(m.scoredPoints, 4);
    expect(m.meanAbsErrorDays, (0 + 2 + 2 + 10) / 4); // 3.5
    expect(m.medianAbsErrorDays, 2); // (2 + 2) / 2
  });

  test('coverage counts only starts that land inside the predicted range', () {
    final run = BacktestRun(
      label: 't',
      points: [
        _point(absError: 0, rangeRadius: 3), // in
        _point(absError: 3, rangeRadius: 3), // in (edge, inclusive)
        _point(absError: 4, rangeRadius: 3), // out
        _point(absError: -10, rangeRadius: 3), // out
      ],
    );
    final m = BacktestMetrics.of(run);
    expect(m.coverage, 0.5);
    expect(m.meanRangeWidthDays, 7); // 2*3 + 1 inclusive
  });

  test('ovulation MAE only averages points that carry a truth signal', () {
    final run = BacktestRun(
      label: 't',
      points: [
        _point(absError: 0, ovulationAbsError: 1),
        _point(absError: 0, ovulationAbsError: 3),
        _point(absError: 0), // no ovulation truth
      ],
    );
    final m = BacktestMetrics.of(run);
    expect(m.ovulationMeanAbsErrorDays, 2); // (1 + 3) / 2
  });

  group('snowball ratio', () {
    test('> 1 when post-outlier errors are worse than the run baseline', () {
      final run = BacktestRun(
        label: 't',
        points: [
          // typical months: ~28-day recent cycle, small error
          for (var i = 0; i < 6; i++)
            _point(absError: 1, recentCycleLength: 28),
          // right after a very long (outlier) cycle: big error
          _point(absError: 12, recentCycleLength: 55),
          _point(absError: 10, recentCycleLength: 52),
        ],
      );
      final s = BacktestMetrics.of(run).snowball!;
      expect(s.postOutlierPoints, 2);
      expect(s.otherPoints, 6);
      expect(s.ratio!, greaterThan(1));
    });

    test('null when there are too few points on one side', () {
      final run = BacktestRun(
        label: 't',
        points: [
          for (var i = 0; i < 6; i++)
            _point(absError: 1, recentCycleLength: 28),
          _point(absError: 12, recentCycleLength: 55), // only one outlier point
        ],
      );
      expect(BacktestMetrics.of(run).snowball, isNull);
    });

    test('null when no recent-cycle-length is recorded', () {
      final run = BacktestRun(
        label: 't',
        points: [for (var i = 0; i < 4; i++) _point(absError: 2)],
      );
      expect(BacktestMetrics.of(run).snowball, isNull);
    });
  });
}
