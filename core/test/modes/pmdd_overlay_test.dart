import 'dart:math';

import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p7.6 — the PMDD cycle-overlay derivation. It is a thin, deterministic wrapper
/// over the p7.4 [cyclePhaseCorrelations] core: each rated day becomes a
/// `'rated'` event, each day whose peak rating reaches [pmddNotableFrom] also
/// becomes a `'notable'` event, and the luteal read is a plain-language mapping
/// of `notable.showsUpMostIn`. No score, no threshold, no diagnosis (§9(12)).
void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start) => Period(
    id: nextId++,
    startDate: start,
    endDate: start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  setUp(() => nextId = 1);

  /// `n` back-to-back 28-day cycles, the first period starting [first]. The last
  /// cycle is left open (current), so `n - 1` are completed.
  List<Cycle> cycles28({required DateTime first, required int n}) =>
      deriveCycles([
        for (var i = 0; i < n; i++) period(first.add(Duration(days: 28 * i))),
      ]);

  // For a 28-day cycle with the period on days 1–4, cyclePhaseTimeline puts:
  //   menstrual d1..d4   follicular d5..d9   ovulatory d10..d16   luteal d17..d28
  DateTime dayIn(DateTime first, int cycle, int day) =>
      first.add(Duration(days: 28 * cycle + (day - 1)));

  PmddDayRating notable(DateTime date) => PmddDayRating(
    date: date,
    items: const {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.lowMood: SymptomSeverity.moderate,
    },
  );

  PmddDayRating mild(DateTime date) => PmddDayRating(
    date: date,
    items: const {PmddSymptom.fatigue: SymptomSeverity.mild},
  );

  PmddDayRating nothing(DateTime date) => PmddDayRating(
    date: date,
    items: const {PmddSymptom.bloating: SymptomSeverity.none},
  );

  test('peakRank / isNotable read the highest item on the day', () {
    expect(notable(epoch).peakRank, SymptomSeverity.severe.rank);
    expect(notable(epoch).isNotable, isTrue);
    expect(mild(epoch).isNotable, isFalse);
    expect(nothing(epoch).isNotable, isFalse);
    expect(nothing(epoch).peakRank, 0);
    expect(PmddDayRating(date: epoch, items: const {}).peakRank, 0);
  });

  test(
    'notable days concentrated in the luteal phase read as runsHigherInLuteal',
    () {
      final first = DateTime(2026, 1, 1);
      final cycles = cycles28(first: first, n: 4); // 3 completed + 1 open
      final ratings = <PmddDayRating>[
        for (var c = 0; c < 3; c++)
          for (final d in const [18, 21, 24]) notable(dayIn(first, c, d)),
      ];

      final overlay = pmddOverlay(
        ratings: ratings,
        cycles: cycles,
        today: DateTime(2026, 4, 1),
      );

      expect(overlay.enoughData, isTrue);
      expect(overlay.lutealRead, PmddLutealRead.runsHigherInLuteal);
      expect(overlay.notableDaysByPhase[CyclePhaseKind.luteal], 9);
      expect(overlay.notableDaysByPhase[CyclePhaseKind.menstrual], 0);
      expect(overlay.notablePlacedDays, 9);
      // Every notable day is also a rated day.
      expect(overlay.ratedDaysByPhase[CyclePhaseKind.luteal], 9);
    },
  );

  test(
    'notable days spread evenly across phases read as noClearLutealPattern',
    () {
      final first = DateTime(2026, 1, 1);
      final cycles = cycles28(first: first, n: 4);
      final ratings = <PmddDayRating>[
        for (var c = 0; c < 3; c++)
          for (final d in const [2, 5, 8, 11, 14, 17, 20, 23, 26])
            notable(dayIn(first, c, d)),
      ];

      final overlay = pmddOverlay(
        ratings: ratings,
        cycles: cycles,
        today: DateTime(2026, 4, 1),
      );

      expect(overlay.enoughData, isTrue);
      expect(overlay.lutealRead, PmddLutealRead.noClearLutealPattern);
      expect(overlay.notablePlacedDays, 27);
    },
  );

  test('a single completed cycle is not enough data', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 2); // 1 completed + 1 open
    final ratings = [
      for (final d in const [18, 19, 20, 21, 22, 23])
        notable(dayIn(first, 0, d)),
    ];

    final overlay = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 2, 15),
    );

    expect(overlay.enoughData, isFalse);
    expect(overlay.lutealRead, PmddLutealRead.notEnoughData);
  });

  test('too few placed notable days is not enough data even with cycles', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    // Only 3 notable luteal days total — below correlationMinPlacedDays (5).
    final ratings = [
      notable(dayIn(first, 0, 20)),
      notable(dayIn(first, 1, 20)),
      notable(dayIn(first, 2, 20)),
    ];

    final overlay = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(overlay.enoughData, isFalse);
    expect(overlay.lutealRead, PmddLutealRead.notEnoughData);
  });

  test('mild-only and none-only days count as rated but never as notable', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final ratings = <PmddDayRating>[
      for (var c = 0; c < 3; c++) ...[
        for (final d in const [18, 21]) notable(dayIn(first, c, d)),
        mild(dayIn(first, c, 6)),
        nothing(dayIn(first, c, 8)),
      ],
    ];

    final overlay = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    // 6 notable days, all luteal.
    expect(overlay.notablePlacedDays, 6);
    expect(overlay.notableDaysByPhase[CyclePhaseKind.follicular], 0);
    // 12 rated days: 6 luteal (notable) + 3 follicular (mild) + 3 follicular
    // (none). d6 and d8 are both follicular for a 28-day cycle.
    expect(overlay.ratedDaysByPhase[CyclePhaseKind.luteal], 6);
    expect(overlay.ratedDaysByPhase[CyclePhaseKind.follicular], 6);
  });

  test('an empty rating stream yields a zeroed, not-enough-data overlay', () {
    final first = DateTime(2026, 1, 1);
    final overlay = pmddOverlay(
      ratings: const [],
      cycles: cycles28(first: first, n: 4),
      today: DateTime(2026, 4, 1),
    );

    expect(overlay.enoughData, isFalse);
    expect(overlay.lutealRead, PmddLutealRead.notEnoughData);
    expect(overlay.notablePlacedDays, 0);
    for (final kind in CyclePhaseKind.values) {
      expect(overlay.ratedDaysByPhase[kind], 0);
      expect(overlay.notableDaysByPhase[kind], 0);
    }
  });

  test('a day with no rated items is ignored entirely', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final ratings = <PmddDayRating>[
      for (var c = 0; c < 3; c++)
        for (final d in const [18, 21, 24]) notable(dayIn(first, c, d)),
      PmddDayRating(date: dayIn(first, 0, 10), items: const {}),
    ];

    final overlay = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(overlay.notablePlacedDays, 9);
    expect(overlay.ratedDaysByPhase[CyclePhaseKind.ovulatory], 0);
  });

  test('ratings dated after today are not counted', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final ratings = <PmddDayRating>[
      for (var c = 0; c < 3; c++)
        for (final d in const [18, 21, 24]) notable(dayIn(first, c, d)),
      // Well past `today` — must be dropped.
      notable(DateTime(2026, 6, 1)),
      notable(DateTime(2026, 6, 4)),
    ];

    final overlay = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(overlay.notablePlacedDays, 9);
  });

  test(
    'a likely-gap cycle and a short cycle in the same history do not crash',
    () {
      // Cycle 0: normal 28 d. Cycle 1: short (20 d). Then a 60-day jump → the
      // interval that follows is flagged isLikelyGap and dropped from the read.
      final periods = [
        period(DateTime(2026, 1, 1)),
        period(DateTime(2026, 1, 21)), // 20-day cycle
        period(DateTime(2026, 2, 10)),
        period(DateTime(2026, 4, 11)), // 60-day interval → likely gap
        period(DateTime(2026, 5, 9)),
      ];
      final cycles = deriveCycles(periods);
      expect(cycles.any((c) => c.isLikelyGap), isTrue);

      final ratings = <PmddDayRating>[
        notable(DateTime(2026, 1, 18)),
        notable(DateTime(2026, 2, 4)),
        notable(DateTime(2026, 2, 26)),
        notable(DateTime(2026, 5, 2)),
        nothing(DateTime(2026, 3, 15)), // inside the gap interval
      ];

      late PmddOverlay overlay;
      expect(
        () => overlay = pmddOverlay(
          ratings: ratings,
          cycles: cycles,
          today: DateTime(2026, 5, 20),
        ),
        returnsNormally,
      );
      // Placed days never exceed the number of rated days fed in.
      expect(overlay.notablePlacedDays, lessThanOrEqualTo(4));
    },
  );

  test('the result is independent of rating order (deterministic)', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final ratings = <PmddDayRating>[
      for (var c = 0; c < 3; c++) ...[
        for (final d in const [18, 21, 24]) notable(dayIn(first, c, d)),
        mild(dayIn(first, c, 6)),
        nothing(dayIn(first, c, 8)),
      ],
    ];

    final ordered = pmddOverlay(
      ratings: ratings,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );
    final shuffled = pmddOverlay(
      ratings: [...ratings]..shuffle(Random(7)),
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(shuffled, ordered);
    expect(shuffled.hashCode, ordered.hashCode);
  });
}
