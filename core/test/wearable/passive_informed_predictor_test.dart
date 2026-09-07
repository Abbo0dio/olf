import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  const inner = AdaptivePredictor();
  final stamp = DateTime.utc(2000);

  /// A steady ~28-day history: 13 period starts, newest-first cycles.
  List<Cycle> steadyCycles() {
    final starts = [
      for (var i = 0; i < 13; i++)
        DateTime(2025, 1, 1).add(Duration(days: 28 * i)),
    ];
    return [
      for (var i = 0; i < starts.length; i++)
        Cycle(
          periodStart: starts[i],
          nextPeriodStart: i + 1 < starts.length ? starts[i + 1] : null,
        ),
    ].reversed.toList();
  }

  BbtEntry bbt(DateTime day, double c) => BbtEntry(
    date: day,
    tempCelsius: c,
    measurementKind: BbtMeasurementKind.sleepingWrist,
    source: 'appleHealth',
    createdAt: stamp,
    updatedAt: stamp,
  );

  /// A passive series for the open cycle with a shift on [shiftDay].
  List<BbtEntry> passiveSeries(DateTime cycleStart, {required int shiftDay}) =>
      [
        for (var d = 0; d <= 22; d++)
          bbt(
            cycleStart.add(Duration(days: d)),
            36.30 + (d >= shiftDay ? 0.35 : 0.0) + ((d * 37) % 7 - 3) * 0.01,
          ),
      ];

  test('no temperatures → result is byte-identical to the inner predictor', () {
    final cycles = steadyCycles();
    final today = cycles.first.periodStart.add(const Duration(days: 20));
    final base = inner.predict(cycles: cycles, today: today);
    final combined = const PassiveInformedPredictor(
      inner: inner,
      temperatures: [],
    ).predict(cycles: cycles, today: today);
    expect(combined, base);
  });

  test('no detectable shift → identical to the inner predictor', () {
    final cycles = steadyCycles();
    final start = cycles.first.periodStart;
    final today = start.add(const Duration(days: 20));
    final flat = [
      for (var d = 0; d <= 20; d++)
        bbt(start.add(Duration(days: d)), 36.30 + ((d * 37) % 7 - 3) * 0.01),
    ];
    final base = inner.predict(cycles: cycles, today: today);
    final combined = PassiveInformedPredictor(
      inner: inner,
      temperatures: flat,
    ).predict(cycles: cycles, today: today);
    expect(combined, base);
  });

  test(
    'a confirmed current-cycle shift re-anchors ONLY the fertile window',
    () {
      final cycles = steadyCycles();
      final start = cycles.first.periodStart;
      final today = start.add(const Duration(days: 22));
      final base = inner.predict(cycles: cycles, today: today)!;

      final combined = PassiveInformedPredictor(
        inner: inner,
        temperatures: passiveSeries(start, shiftDay: 13),
      ).predict(cycles: cycles, today: today)!;

      // Every next-period field is untouched.
      expect(combined.nextPeriod, base.nextPeriod);
      expect(combined.nextPeriodExpected, base.nextPeriodExpected);
      expect(combined.confidence, base.confidence);
      expect(combined.basedOnCycles, base.basedOnCycles);
      expect(combined.status, base.status);
      expect(combined.daysPastExpected, base.daysPastExpected);

      // The fertile window moved to sit around the observed ovulation
      // (shift day 13 → ovulation ~day 12 of the open cycle).
      final observedOvulation = start.add(const Duration(days: 12));
      final predictedOvulation = combined.fertileWindow.start.add(
        const Duration(days: 5),
      );
      expect(
        predictedOvulation.difference(observedOvulation).inDays.abs(),
        lessThanOrEqualTo(1),
      );
      expect(combined.fertileWindow, isNot(base.fertileWindow));
    },
  );

  test('null base (thin history) stays null', () {
    final combined = PassiveInformedPredictor(
      inner: inner,
      temperatures: passiveSeries(DateTime(2026, 1, 1), shiftDay: 13),
    ).predict(cycles: const [], today: DateTime(2026, 2, 1));
    expect(combined, isNull);
  });

  test('a shift dated in the future relative to today is ignored', () {
    final cycles = steadyCycles();
    final start = cycles.first.periodStart;
    // today is day 10 — the elevated run (from day 13) is not in-window yet.
    final today = start.add(const Duration(days: 10));
    final base = inner.predict(cycles: cycles, today: today);
    final combined = PassiveInformedPredictor(
      inner: inner,
      temperatures: passiveSeries(start, shiftDay: 13),
    ).predict(cycles: cycles, today: today);
    expect(combined, base);
  });

  test('editing the period history re-derives — a correction wins', () {
    final start = DateTime(2025, 1, 1).add(const Duration(days: 28 * 12));
    final withShift = PassiveInformedPredictor(
      inner: inner,
      temperatures: passiveSeries(start, shiftDay: 13),
    );

    final before = withShift.predict(
      cycles: steadyCycles(),
      today: start.add(const Duration(days: 22)),
    )!;

    // The user logs today's period start → the open cycle is now a fresh one
    // that starts today, so the old passive series is out of its window and the
    // fertile window falls back to the pure forecast.
    final corrected = [
      Cycle(periodStart: start.add(const Duration(days: 22))),
      ...steadyCycles().map(
        (c) => c.periodStart == start
            ? Cycle(
                periodStart: c.periodStart,
                nextPeriodStart: start.add(const Duration(days: 22)),
              )
            : c,
      ),
    ];
    final after = withShift.predict(
      cycles: corrected,
      today: start.add(const Duration(days: 23)),
    )!;
    final freshBase = inner.predict(
      cycles: corrected,
      today: start.add(const Duration(days: 23)),
    )!;
    expect(after.fertileWindow, freshBase.fertileWindow);
    expect(after.fertileWindow, isNot(before.fertileWindow));
  });
}
