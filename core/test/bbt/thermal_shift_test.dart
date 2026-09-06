import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final stamp = DateTime(2026);

  BbtEntry temp(
    DateTime date,
    double celsius, {
    BbtMeasurementKind kind = BbtMeasurementKind.basal,
  }) => BbtEntry(
    date: date,
    tempCelsius: celsius,
    source: 'manual',
    measurementKind: kind,
    createdAt: stamp,
    updatedAt: stamp,
  );

  /// Readings starting [from], one per day, at the given temperatures.
  List<BbtEntry> series(DateTime from, List<double> temps) => [
    for (var i = 0; i < temps.length; i++)
      temp(from.add(Duration(days: i)), temps[i]),
  ];

  final cycleStart = DateTime(2026, 3, 1);

  test('null when fewer than 6 baseline + 3 elevated readings', () {
    final entries = series(cycleStart, const [36.4, 36.45, 36.4, 36.7, 36.75]);
    expect(
      thermalShift(
        entries,
        cycleStart: cycleStart,
        today: DateTime(2026, 4, 1),
      ),
      isNull,
    );
  });

  test('null when temperatures stay flat', () {
    final entries = series(cycleStart, const [
      36.4,
      36.42,
      36.38,
      36.41,
      36.4,
      36.43,
      36.39,
      36.42,
      36.4,
      36.41,
    ]);
    expect(
      thermalShift(
        entries,
        cycleStart: cycleStart,
        today: DateTime(2026, 4, 1),
      ),
      isNull,
    );
  });

  test('detects a classic 3-over-6 rise; ovulation is the day before', () {
    // 6 low readings ~36.40, then 3 clearly ≥ 0.2 °C above the coverline.
    final entries = series(cycleStart, const [
      36.40, 36.42, 36.38, 36.41, 36.40, 36.43, // baseline (coverline 36.43)
      36.70, 36.72, 36.68, // elevated
      36.71,
    ]);
    final shift = thermalShift(
      entries,
      cycleStart: cycleStart,
      today: DateTime(2026, 4, 1),
    );
    expect(shift, isNotNull);
    // 7th reading (index 6) is 2026-03-07.
    expect(shift!.shiftDate, DateTime(2026, 3, 7));
    expect(shift.estimatedOvulation, DateTime(2026, 3, 6));
    expect(shift.riseCelsius, closeTo(0.27, 0.001));
  });

  test('a single fever spike does not count — needs 3 sustained', () {
    final entries = series(cycleStart, const [
      36.40, 36.42, 36.38, 36.41, 36.40, 36.43,
      36.90, // one spike
      36.41, 36.40, 36.42,
    ]);
    expect(
      thermalShift(
        entries,
        cycleStart: cycleStart,
        today: DateTime(2026, 4, 1),
      ),
      isNull,
    );
  });

  test('picks the earliest confirmed run when the shift is sustained', () {
    final entries = series(cycleStart, const [
      36.40,
      36.42,
      36.38,
      36.41,
      36.40,
      36.43,
      36.70,
      36.72,
      36.71,
      36.73,
      36.70,
      36.72,
    ]);
    final shift = thermalShift(
      entries,
      cycleStart: cycleStart,
      today: DateTime(2026, 4, 1),
    );
    expect(shift!.shiftDate, DateTime(2026, 3, 7));
  });

  test('ignores readings before the cycle start or after today', () {
    final entries = [
      ...series(DateTime(2026, 2, 20), const [36.7, 36.7, 36.7]), // pre-cycle
      ...series(cycleStart, const [
        36.40,
        36.42,
        36.38,
        36.41,
        36.40,
        36.43,
        36.70,
        36.72,
        36.68,
      ]),
      temp(DateTime(2026, 3, 20), 36.9), // after `today`
    ];
    final shift = thermalShift(
      entries,
      cycleStart: cycleStart,
      today: DateTime(2026, 3, 10),
    );
    expect(shift!.shiftDate, DateTime(2026, 3, 7));
  });

  test('deterministic and clock-injected: shifting every date by N days '
      'shifts only the dates', () {
    List<double> temps() => const [
      36.40,
      36.42,
      36.38,
      36.41,
      36.40,
      36.43,
      36.70,
      36.72,
      36.68,
    ];
    final a = thermalShift(
      series(cycleStart, temps()),
      cycleStart: cycleStart,
      today: DateTime(2026, 4, 1),
    )!;
    final b = thermalShift(
      series(cycleStart.add(const Duration(days: 40)), temps()),
      cycleStart: cycleStart.add(const Duration(days: 40)),
      today: DateTime(2026, 5, 11),
    )!;
    expect(b.shiftDate, a.shiftDate.add(const Duration(days: 40)));
    expect(
      b.estimatedOvulation,
      a.estimatedOvulation.add(const Duration(days: 40)),
    );
    expect(b.riseCelsius, a.riseCelsius);
  });

  // p8.1a: a passive Apple Watch sleeping-wrist reading shares the
  // `bbt_entries` day slot but is not a basal body temperature. `thermalShift`
  // must ignore it entirely — a mixed-kind history produces the identical shift
  // to the same history with the `sleepingWrist` rows removed.
  test('sleepingWrist readings are invisible to the thermal shift', () {
    final basal = series(cycleStart, const [
      36.40,
      36.42,
      36.38,
      36.41,
      36.40,
      36.43,
      36.70,
      36.72,
      36.68,
      36.71,
    ]);

    // Interleave wrist readings that, if counted, would wreck the coverline and
    // the 3-over-6 run (wildly hot early, ice-cold during the rise).
    final wrist = [
      temp(
        cycleStart.add(const Duration(days: 1)),
        38.5,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
      temp(
        cycleStart.add(const Duration(days: 3)),
        38.9,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
      temp(
        cycleStart.add(const Duration(days: 7)),
        35.1,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
    ];

    final basalOnly = thermalShift(
      basal,
      cycleStart: cycleStart,
      today: DateTime(2026, 4, 1),
    );
    final mixed = thermalShift(
      [...basal, ...wrist],
      cycleStart: cycleStart,
      today: DateTime(2026, 4, 1),
    );

    expect(basalOnly, isNotNull);
    expect(mixed, basalOnly);
  });
}
