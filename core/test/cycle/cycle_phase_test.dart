import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  // A representative 28-day cycle: period 1st–5th, fertile window centered
  // around day 14, next period expected on day 28.
  final periodStart = DateTime(2026, 1, 1);
  final periodEnd = DateTime(2026, 1, 5);
  final fertileWindow = DateRange(DateTime(2026, 1, 12), DateTime(2026, 1, 16));
  final nextPeriodExpected = DateTime(2026, 1, 28);

  Cycle cycle({
    DateTime? start,
    DateTime? end,
    DateTime? nextStart,
    PregnancyEndKind? interruptedBy,
  }) => Cycle(
    periodStart: start ?? periodStart,
    periodEnd: end ?? periodEnd,
    nextPeriodStart: nextStart,
    interruptedBy: interruptedBy,
  );

  CyclePrediction prediction({
    DateRange? fertile,
    DateTime? expected,
    PredictionStatus status = PredictionStatus.upcoming,
    int? daysPastExpected,
  }) => CyclePrediction(
    nextPeriod: DateRange(
      addDays(nextPeriodExpected, -2),
      addDays(nextPeriodExpected, 2),
    ),
    nextPeriodExpected: expected ?? nextPeriodExpected,
    fertileWindow: fertile ?? fertileWindow,
    confidence: PredictionConfidence.medium,
    basedOnCycles: 6,
    status: status,
    daysPastExpected: daysPastExpected,
  );

  group('currentCyclePhase', () {
    test('no cycle yields no phase', () {
      expect(
        currentCyclePhase(
          cycle: null,
          prediction: prediction(),
          today: DateTime(2026, 1, 10),
        ),
        isNull,
      );
    });

    test('no prediction yields no phase', () {
      expect(
        currentCyclePhase(
          cycle: cycle(),
          prediction: null,
          today: DateTime(2026, 1, 10),
        ),
        isNull,
      );
    });

    test('a likely-gap cycle yields no phase', () {
      final gapCycle = Cycle(
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 5),
        nextPeriodStart: DateTime(2026, 1, 1), // > 45 days later
      );
      expect(
        currentCyclePhase(
          cycle: gapCycle,
          prediction: prediction(),
          today: DateTime(2025, 6, 1),
        ),
        isNull,
      );
    });

    test('a pregnancy-gap cycle yields no phase', () {
      final pregCycle = cycle(interruptedBy: PregnancyEndKind.birth);
      expect(
        currentCyclePhase(
          cycle: pregCycle,
          prediction: prediction(),
          today: DateTime(2026, 1, 10),
        ),
        isNull,
      );
    });

    test('a period logged in the future yields no phase for today', () {
      final future = cycle(
        start: DateTime(2026, 2, 1),
        end: DateTime(2026, 2, 5),
      );
      expect(
        currentCyclePhase(
          cycle: future,
          prediction: prediction(),
          today: DateTime(2026, 1, 10),
        ),
        isNull,
      );
    });

    test(
      'a degenerate fertile window (not after the period) yields no phase',
      () {
        final overlapping = prediction(
          fertile: DateRange(DateTime(2026, 1, 3), DateTime(2026, 1, 5)),
        );
        expect(
          currentCyclePhase(
            cycle: cycle(),
            prediction: overlapping,
            today: DateTime(2026, 1, 10),
          ),
          isNull,
        );
      },
    );

    test('day 1 of the period is menstrual', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: periodStart,
      )!;
      expect(phase.current.kind, CyclePhaseKind.menstrual);
      expect(phase.dayInPhase, 1);
    });

    test('the last day of the logged period is still menstrual', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: periodEnd,
      )!;
      expect(phase.current.kind, CyclePhaseKind.menstrual);
      expect(phase.dayInPhase, 5);
    });

    test('the day after the period ends is follicular', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: addDays(periodEnd, 1),
      )!;
      expect(phase.current.kind, CyclePhaseKind.follicular);
      expect(phase.dayInPhase, 1);
    });

    test('the day before the fertile window is the last follicular day', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: addDays(fertileWindow.start, -1),
      )!;
      expect(phase.current.kind, CyclePhaseKind.follicular);
    });

    test('the fertile window is ovulatory, start to end inclusive', () {
      for (final day in [
        fertileWindow.start,
        DateTime(2026, 1, 14),
        fertileWindow.end,
      ]) {
        final phase = currentCyclePhase(
          cycle: cycle(),
          prediction: prediction(),
          today: day,
        )!;
        expect(phase.current.kind, CyclePhaseKind.ovulatory, reason: '$day');
      }
    });

    test('the day after the fertile window is the first luteal day', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: addDays(fertileWindow.end, 1),
      )!;
      expect(phase.current.kind, CyclePhaseKind.luteal);
      expect(phase.dayInPhase, 1);
    });

    test('the expected next-period day is still luteal', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: nextPeriodExpected,
      )!;
      expect(phase.current.kind, CyclePhaseKind.luteal);
    });

    test(
      'overdue (past the expected day, no new period logged) stays luteal, never a fabricated fifth phase',
      () {
        final phase = currentCyclePhase(
          cycle: cycle(),
          prediction: prediction(
            status: PredictionStatus.overdue,
            daysPastExpected: 6,
          ),
          today: addDays(nextPeriodExpected, 6),
        )!;
        expect(phase.current.kind, CyclePhaseKind.luteal);
        // Honest overshoot, not clamped to look "on schedule".
        expect(phase.dayInPhase, greaterThan(phase.current.lengthInDays));
      },
    );

    test(
      'an ongoing period with no end logged runs menstrual through today',
      () {
        final open = cycle(end: null);
        final phase = currentCyclePhase(
          cycle: open,
          prediction: prediction(),
          today: addDays(periodStart, 2),
        )!;
        expect(phase.current.kind, CyclePhaseKind.menstrual);
        expect(phase.dayInPhase, 3);
        // The trailing phases are still reported, just pushed out.
        expect(phase.segments, hasLength(4));
      },
    );

    test(
      'a very short follicular estimate collapses to zero length without breaking the wheel',
      () {
        final tight = prediction(
          fertile: DateRange(addDays(periodEnd, 1), addDays(periodEnd, 5)),
        );
        final phase = currentCyclePhase(
          cycle: cycle(),
          prediction: tight,
          today: periodEnd,
        )!;
        final follicular = phase.segments[1];
        expect(follicular.kind, CyclePhaseKind.follicular);
        expect(follicular.lengthInDays, 0);
        // No day ever lands in a zero-length segment — period end flows
        // straight into ovulatory the next day, never into an empty phase.
        expect(follicular.contains(addDays(periodEnd, 1)), isFalse);
      },
    );

    test('segments are always the four phases in cycle order', () {
      final phase = currentCyclePhase(
        cycle: cycle(),
        prediction: prediction(),
        today: periodStart,
      )!;
      expect(phase.segments.map((s) => s.kind), [
        CyclePhaseKind.menstrual,
        CyclePhaseKind.follicular,
        CyclePhaseKind.ovulatory,
        CyclePhaseKind.luteal,
      ]);
    });
  });
}
