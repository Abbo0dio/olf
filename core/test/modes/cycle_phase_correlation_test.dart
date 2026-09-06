import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

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

  /// `n` back-to-back 28-day cycles, the first period starting [first]. Returns
  /// the derived cycles (newest first); the last one is left open (current).
  List<Cycle> cycles28({required DateTime first, required int n}) {
    final periods = <Period>[
      for (var i = 0; i < n; i++) period(first.add(Duration(days: 28 * i))),
    ];
    return deriveCycles(periods);
  }

  // For a 28-day cycle with the period on days 1–4, cyclePhaseTimeline puts:
  //   menstrual  d1..d4      follicular d5..d9
  //   ovulatory  d10..d16    luteal     d17..d28
  PhaseEvent onDay(DateTime cycleStart, int day, String category) => PhaseEvent(
    day: cycleStart.add(Duration(days: day - 1)),
    category: category,
  );

  test('an even per-day spread reads as no clear pattern', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4); // 3 completed + 1 open
    // Log "bloating" every 3rd day across each completed cycle — it lands in
    // every phase roughly in proportion to that phase's length.
    final events = <PhaseEvent>[
      for (var c = 0; c < 3; c++)
        for (final d in const [2, 5, 8, 11, 14, 17, 20, 23, 26])
          onDay(first.add(Duration(days: 28 * c)), d, 'bloating'),
    ];

    final result = cyclePhaseCorrelations(
      events: events,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(result, hasLength(1));
    final bloating = result.single;
    expect(bloating.category, 'bloating');
    expect(bloating.enoughData, isTrue);
    expect(bloating.showsUpMostIn, isNull);
    expect(bloating.placedDays, 27);
  });

  test('a symptom concentrated in one phase names that phase', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    // "cramps" only ever logged on luteal days (d17..d28).
    final events = <PhaseEvent>[
      for (var c = 0; c < 3; c++)
        for (final d in const [18, 21, 24])
          onDay(first.add(Duration(days: 28 * c)), d, 'cramps'),
    ];

    final cramps = cyclePhaseCorrelations(
      events: events,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    ).single;

    expect(cramps.enoughData, isTrue);
    expect(cramps.showsUpMostIn, CyclePhaseKind.luteal);
    expect(cramps.daysByPhase[CyclePhaseKind.luteal], 9);
    expect(cramps.daysByPhase[CyclePhaseKind.menstrual], 0);
  });

  test('sub-threshold history reads as not enough data', () {
    final first = DateTime(2026, 1, 1);

    // Only one completed cycle — below the cycle threshold even with many days.
    final oneCycle = cyclePhaseCorrelations(
      events: [
        for (final d in const [18, 19, 20, 21, 22, 23])
          onDay(first, d, 'cramps'),
      ],
      cycles: cycles28(first: first, n: 2),
      today: DateTime(2026, 3, 1),
    ).single;
    expect(oneCycle.enoughData, isFalse);
    expect(oneCycle.showsUpMostIn, isNull);
    expect(oneCycle.totalDays, 6);

    // Enough cycles, but the symptom itself has too few placed days.
    final fewDays = cyclePhaseCorrelations(
      events: [
        for (var c = 0; c < 3; c++)
          onDay(first.add(Duration(days: 28 * c)), 20, 'cramps'),
      ],
      cycles: cycles28(first: first, n: 4),
      today: DateTime(2026, 4, 1),
    ).single;
    expect(fewDays.enoughData, isFalse);
    expect(fewDays.placedDays, 3);
  });

  test('days outside any phase segment count toward totalDays only', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final events = <PhaseEvent>[
      // three luteal days in a real cycle …
      onDay(first, 18, 'cramps'),
      onDay(first, 20, 'cramps'),
      onDay(first, 22, 'cramps'),
      // … plus two logged well before the first cycle even starts
      PhaseEvent(day: DateTime(2025, 6, 1), category: 'cramps'),
      PhaseEvent(day: DateTime(2025, 6, 2), category: 'cramps'),
    ];

    final cramps = cyclePhaseCorrelations(
      events: events,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    ).single;

    expect(cramps.totalDays, 5);
    expect(cramps.placedDays, 3);
  });

  test('is deterministic and ignores events dated after today', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final events = <PhaseEvent>[
      for (var c = 0; c < 3; c++)
        for (final d in const [18, 21, 24])
          onDay(first.add(Duration(days: 28 * c)), d, 'cramps'),
      // a future-dated entry that must be excluded
      PhaseEvent(day: DateTime(2027, 1, 1), category: 'cramps'),
    ];

    final a = cyclePhaseCorrelations(
      events: events,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );
    final b = cyclePhaseCorrelations(
      events: events.reversed,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );

    expect(a.single.totalDays, 9); // the 2027 entry dropped
    expect(a.single.daysByPhase, b.single.daysByPhase);
    expect(a.single.showsUpMostIn, b.single.showsUpMostIn);
  });

  test('results are ordered by category', () {
    final first = DateTime(2026, 1, 1);
    final cycles = cycles28(first: first, n: 4);
    final events = <PhaseEvent>[
      for (var c = 0; c < 3; c++) ...[
        onDay(first.add(Duration(days: 28 * c)), 20, 'zzz'),
        onDay(first.add(Duration(days: 28 * c)), 6, 'aaa'),
      ],
    ];

    final result = cyclePhaseCorrelations(
      events: events,
      cycles: cycles,
      today: DateTime(2026, 4, 1),
    );
    expect(result.map((r) => r.category), ['aaa', 'zzz']);
  });
}
