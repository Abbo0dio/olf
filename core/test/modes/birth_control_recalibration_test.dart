import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  BirthControlEntry entry(
    BirthControlMethod method,
    DateTime startedOn, [
    DateTime? endedOn,
  ]) => BirthControlEntry(
    id: nextId++,
    method: method,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: epoch,
    updatedAt: epoch,
  );

  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end ?? start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// Cycles from a run of period starts, newest first (as `deriveCycles` gives).
  List<Cycle> cyclesFrom(List<DateTime> starts) =>
      deriveCycles([for (final s in starts) period(s)]);

  setUp(() => nextId = 1);

  test('null when there is no birth-control history at all', () {
    expect(
      deriveBirthControlRecalibration(
        entries: const [],
        cycles: const [],
        today: DateTime(2026, 6, 1),
      ),
      isNull,
    );
  });

  test('null for a non-hormonal method only (condom)', () {
    expect(
      deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.condom, DateTime(2026, 1, 1))],
        cycles: const [],
        today: DateTime(2026, 3, 1),
      ),
      isNull,
    );
  });

  test('iud and other are not treated as hormonal', () {
    for (final m in [BirthControlMethod.iud, BirthControlMethod.other]) {
      expect(
        deriveBirthControlRecalibration(
          entries: [entry(m, DateTime(2026, 1, 1))],
          cycles: const [],
          today: DateTime(2026, 2, 1),
        ),
        isNull,
        reason: '$m should not raise a recalibration note',
      );
    }
  });

  group('starting hormonal BC', () {
    test(
      'open hormonal entry inside the window → active, forecast withheld',
      () {
        final r = deriveBirthControlRecalibration(
          entries: [entry(BirthControlMethod.pill, DateTime(2026, 5, 1))],
          cycles: const [],
          today: DateTime(2026, 6, 1),
        );

        expect(r, isNotNull);
        expect(r!.direction, BirthControlSwitchDirection.started);
        expect(r.switchDate, DateTime(2026, 5, 1));
        expect(r.daysSinceSwitch, 31);
        expect(r.windowElapsed, isFalse);
        expect(r.enoughPostSwitchCycles, isFalse);
        expect(r.active, isTrue);
        expect(r.daysRemaining, 59);
      },
    );

    test('window elapsed → inactive (prediction restored)', () {
      final r = deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.patch, DateTime(2026, 1, 1))],
        cycles: const [],
        today: DateTime(2026, 5, 1), // 120 days later, window is 90
      );

      expect(r!.windowElapsed, isTrue);
      expect(r.active, isFalse);
      expect(r.daysRemaining, 0);
    });

    test(
      'enough post-switch cycles → cleared early even inside the window',
      () {
        // Switch on Jan 1; three completed post-switch cycles by mid-Mar.
        final r = deriveBirthControlRecalibration(
          entries: [entry(BirthControlMethod.ring, DateTime(2026, 1, 1))],
          cycles: cyclesFrom([
            DateTime(2026, 1, 10),
            DateTime(2026, 2, 7),
            DateTime(2026, 3, 7),
            DateTime(2026, 4, 4), // opens the 4th (current) cycle
          ]),
          today: DateTime(2026, 3, 20),
        );

        expect(r!.postSwitchCycleCount, 3);
        expect(r.enoughPostSwitchCycles, isTrue);
        expect(r.windowElapsed, isFalse);
        expect(r.active, isFalse);
      },
    );

    test('two post-switch cycles is not enough yet', () {
      final r = deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.ring, DateTime(2026, 1, 1))],
        cycles: cyclesFrom([
          DateTime(2026, 1, 10),
          DateTime(2026, 2, 7),
          DateTime(2026, 3, 7), // opens the current cycle → 2 completed
        ]),
        today: DateTime(2026, 3, 20),
      );

      expect(r!.postSwitchCycleCount, 2);
      expect(r.active, isTrue);
    });

    test('pre-switch cycles are not counted', () {
      final r = deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.pill, DateTime(2026, 3, 1))],
        cycles: cyclesFrom([
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 29),
          DateTime(2026, 2, 26), // all before the switch
        ]),
        today: DateTime(2026, 4, 1),
      );

      expect(r!.postSwitchCycleCount, 0);
      expect(r.active, isTrue);
    });
  });

  group('stopping hormonal BC', () {
    test('current open entry is non-hormonal → reads the hormonal end', () {
      final r = deriveBirthControlRecalibration(
        entries: [
          entry(
            BirthControlMethod.pill,
            DateTime(2025, 6, 1),
            DateTime(2026, 4, 30),
          ),
          entry(BirthControlMethod.condom, DateTime(2026, 5, 1)),
        ],
        cycles: const [],
        today: DateTime(2026, 5, 20),
      );

      expect(r!.direction, BirthControlSwitchDirection.stopped);
      expect(r.switchDate, DateTime(2026, 4, 30));
      expect(r.active, isTrue);
    });

    test('hormonal entry ended and nothing open → reads the end', () {
      final r = deriveBirthControlRecalibration(
        entries: [
          entry(
            BirthControlMethod.injection,
            DateTime(2025, 1, 1),
            DateTime(2026, 5, 10),
          ),
        ],
        cycles: const [],
        today: DateTime(2026, 6, 1),
      );

      expect(r!.direction, BirthControlSwitchDirection.stopped);
      expect(r.switchDate, DateTime(2026, 5, 10));
    });

    test('hormonal → hormonal switch reads as a fresh start', () {
      final r = deriveBirthControlRecalibration(
        entries: [
          entry(
            BirthControlMethod.pill,
            DateTime(2025, 1, 1),
            DateTime(2026, 4, 30),
          ),
          entry(BirthControlMethod.ring, DateTime(2026, 5, 1)),
        ],
        cycles: const [],
        today: DateTime(2026, 5, 15),
      );

      expect(r!.direction, BirthControlSwitchDirection.started);
      expect(r.switchDate, DateTime(2026, 5, 1));
    });
  });

  group('dismissal', () {
    test('dismissed at/after the switch → inactive', () {
      final r = deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.pill, DateTime(2026, 5, 1))],
        cycles: const [],
        today: DateTime(2026, 5, 20),
        dismissedAt: DateTime(2026, 5, 10, 9, 30),
      );

      expect(r!.dismissed, isTrue);
      expect(r.active, isFalse);
    });

    test('dismissal before the switch does not apply', () {
      final r = deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.pill, DateTime(2026, 5, 1))],
        cycles: const [],
        today: DateTime(2026, 5, 20),
        dismissedAt: DateTime(2026, 4, 1),
      );

      expect(r!.dismissed, isFalse);
      expect(r.active, isTrue);
    });

    test('a newer switch after the dismissal brings the note back', () {
      final r = deriveBirthControlRecalibration(
        entries: [
          entry(
            BirthControlMethod.pill,
            DateTime(2026, 1, 1),
            DateTime(2026, 2, 1),
          ),
          entry(BirthControlMethod.ring, DateTime(2026, 5, 1)),
        ],
        cycles: const [],
        today: DateTime(2026, 5, 20),
        dismissedAt: DateTime(2026, 3, 1),
      );

      expect(r!.switchDate, DateTime(2026, 5, 1));
      expect(r.dismissed, isFalse);
      expect(r.active, isTrue);
    });
  });

  test('a switch dated in the future → null', () {
    expect(
      deriveBirthControlRecalibration(
        entries: [entry(BirthControlMethod.pill, DateTime(2026, 7, 1))],
        cycles: const [],
        today: DateTime(2026, 6, 1),
      ),
      isNull,
    );
  });

  test('likely-gap and pregnancy-gap cycles do not count as post-switch', () {
    final r = deriveBirthControlRecalibration(
      entries: [entry(BirthControlMethod.pill, DateTime(2026, 1, 1))],
      cycles: cyclesFrom([
        DateTime(2026, 1, 10),
        DateTime(2026, 4, 1), // ~81-day gap → isLikelyGap
        DateTime(2026, 4, 29),
      ]),
      today: DateTime(2026, 5, 10),
      windowDays: 365,
    );

    // Only the Jan 10 → Apr 1 (gap) and Apr 1 → Apr 29 cycles are completed;
    // the gap one is excluded, so just one counts.
    expect(r!.postSwitchCycleCount, 1);
    expect(r.enoughPostSwitchCycles, isFalse);
    expect(r.active, isTrue);
  });

  test('window and cycle thresholds are overridable', () {
    final r = deriveBirthControlRecalibration(
      entries: [entry(BirthControlMethod.pill, DateTime(2026, 5, 1))],
      cycles: const [],
      today: DateTime(2026, 5, 20),
      windowDays: 10,
    );

    expect(r!.windowElapsed, isTrue);
    expect(r.active, isFalse);
  });
}
