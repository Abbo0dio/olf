import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// A predictor whose output is fully controlled by the test.
class _FixedPredictor implements Predictor {
  _FixedPredictor(this._build);
  final CyclePrediction? Function(List<Cycle> cycles, DateTime today) _build;

  @override
  CyclePrediction? predict({
    required List<Cycle> cycles,
    required DateTime today,
  }) => _build(cycles, today);
}

void main() {
  // Six periods, exactly 28 days apart: 2024-01-01, 01-29, 02-26, 03-25,
  // 04-22, 05-20.
  final starts = <DateTime>[
    for (var i = 0; i < 6; i++)
      DateTime(2024, 1, 1).add(Duration(days: 28 * i)),
  ];

  test('replays every completed-cycle boundary from minCompletedCycles', () {
    final run = runBacktest(
      periodStarts: starts,
      predictor: const RobustPredictor(),
    );
    // k from 1..(6-2)=4 → 4 decision points.
    expect(run.points.length, 4);
    expect(run.points.map((p) => p.completedCycles), [1, 2, 3, 4]);
    // asOf is always the day after the anchor start.
    for (final p in run.points) {
      expect(p.asOf.difference(DateTime(2024, 1, 1)).inDays % 28, 1);
    }
    // Ground truth is the following start.
    expect(run.points.first.actualNextStart, DateTime(2024, 1, 29 + 28));
  });

  test('a perfect predictor scores zero error and full coverage', () {
    final run = runBacktest(
      periodStarts: starts,
      predictor: _FixedPredictor((cycles, today) {
        final anchor = cycles.first.periodStart;
        final exact = anchor.add(const Duration(days: 28));
        return CyclePrediction(
          nextPeriod: DateRange(exact, exact),
          nextPeriodExpected: exact,
          fertileWindow: DateRange(
            exact.subtract(const Duration(days: 19)),
            exact.subtract(const Duration(days: 13)),
          ),
          confidence: PredictionConfidence.high,
          basedOnCycles: cycles.length - 1,
          status: PredictionStatus.upcoming,
          daysPastExpected: null,
        );
      }),
    );
    final m = BacktestMetrics.of(run);
    expect(m.scoredPoints, 4);
    expect(m.meanAbsErrorDays, 0);
    expect(m.medianAbsErrorDays, 0);
    expect(m.coverage, 1.0);
  });

  test(
    'a null-returning predictor is scored as "no prediction", not a crash',
    () {
      final run = runBacktest(
        periodStarts: starts,
        predictor: _FixedPredictor((_, _) => null),
      );
      expect(run.scoredCount, 0);
      expect(run.noPredictionCount, run.points.length);

      final m = BacktestMetrics.of(run);
      expect(m.scoredPoints, 0);
      expect(m.meanAbsErrorDays, isNull);
      expect(m.medianAbsErrorDays, isNull);
      expect(m.coverage, isNull);
      expect(m.snowball, isNull);
    },
  );

  test('the predictor never sees a cycle it could not have known', () {
    late int maxSeen;
    maxSeen = 0;
    runBacktest(
      periodStarts: starts,
      predictor: _FixedPredictor((cycles, today) {
        // newest first; the newest start must be < asOf and every start known
        // must be <= the anchor.
        for (final c in cycles) {
          expect(c.periodStart.isBefore(today), isTrue);
        }
        maxSeen = cycles.length > maxSeen ? cycles.length : maxSeen;
        return null;
      }),
    );
    // last decision point sees 5 starts (4 completed + open).
    expect(maxSeen, 5);
  });

  test('ovulation error is null without a truth signal, set with one', () {
    final history = SyntheticHistories.regular(seed: 1, cycles: 8);
    final withTruth = runBacktestOn(
      history,
      predictor: const RobustPredictor(),
    );
    final withoutTruth = runBacktest(
      periodStarts: history.periodStarts,
      predictor: const RobustPredictor(),
    );
    expect(BacktestMetrics.of(withTruth).ovulationMeanAbsErrorDays, isNotNull);
    expect(BacktestMetrics.of(withoutTruth).ovulationMeanAbsErrorDays, isNull);
  });
}
