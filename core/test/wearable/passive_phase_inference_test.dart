import 'dart:math' as math;

import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final stamp = DateTime.utc(2000);
  final cycleStart = DateTime(2026, 3, 1);

  BbtEntry row(
    int dayOffset,
    double celsius, {
    BbtMeasurementKind kind = BbtMeasurementKind.basal,
  }) => BbtEntry(
    date: addDays(cycleStart, dayOffset),
    tempCelsius: celsius,
    measurementKind: kind,
    source: 'appleHealth',
    createdAt: stamp,
    updatedAt: stamp,
  );

  /// One open cycle starting at [cycleStart].
  List<Cycle> openCycle() => [Cycle(periodStart: cycleStart)];

  /// A clean series: 10 low-phase days ~36.30, then a +0.35 step from
  /// [shiftDayOffset] through [lastDayOffset]. `ovulation` truth is
  /// `shiftDayOffset - 1`.
  List<BbtEntry> cleanSeries({
    int shiftDayOffset = 13,
    int lastDayOffset = 24,
    BbtMeasurementKind kind = BbtMeasurementKind.basal,
    double low = 36.30,
    double rise = 0.35,
    Set<int> drop = const {},
  }) {
    final out = <BbtEntry>[];
    // tiny deterministic wiggle so the coverline is not a flat tie
    double wiggle(int d) => ((d * 37) % 7 - 3) * 0.01; // -0.03..0.03
    for (var d = 0; d <= lastDayOffset; d++) {
      if (drop.contains(d)) continue;
      final elevated = d >= shiftDayOffset;
      out.add(row(d, low + (elevated ? rise : 0.0) + wiggle(d), kind: kind));
    }
    return out;
  }

  group('inferPassivePhase — detection', () {
    test('confirms a post-ovulatory shift and estimates ovulation ±1 day', () {
      final est = inferPassivePhase(
        temperatures: cleanSeries(shiftDayOffset: 13),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );

      expect(est, isNotNull);
      expect(est!.read, PassivePhaseRead.ovulationLikelyPassed);
      expect(est.trackUsed, PassiveSignalTrack.basal);
      // shift day is offset 13 → estimated ovulation is offset 12.
      final trueOvulation = addDays(cycleStart, 12);
      expect(
        (daysBetween(trueOvulation, est.estimatedOvulation)).abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('input order does not change the result (deterministic)', () {
      final series = cleanSeries();
      final forward = inferPassivePhase(
        temperatures: series,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      final shuffled = inferPassivePhase(
        temperatures: [...series]..shuffle(math.Random(9)),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(shuffled, forward);
    });

    test('a wrist-only track works and is reported as such', () {
      final est = inferPassivePhase(
        temperatures: cleanSeries(kind: BbtMeasurementKind.sleepingWrist),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(est, isNotNull);
      expect(est!.trackUsed, PassiveSignalTrack.sleepingWrist);
    });

    test('the basal track is preferred when both have enough readings', () {
      final basal = cleanSeries();
      final wrist = cleanSeries(kind: BbtMeasurementKind.sleepingWrist);
      final est = inferPassivePhase(
        temperatures: [...basal, ...wrist],
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(est!.trackUsed, PassiveSignalTrack.basal);
    });

    test('HRV / sleep args are accepted and do not change the output', () {
      final series = cleanSeries();
      final without = inferPassivePhase(
        temperatures: series,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      final withExtras = inferPassivePhase(
        temperatures: series,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
        hrv: [
          PassiveHrvSample(at: addDays(cycleStart, 20), millis: 42),
          PassiveHrvSample(at: addDays(cycleStart, 21), millis: 39),
        ],
        sleep: [
          PassiveSleepSample(
            night: addDays(cycleStart, 20),
            minutesAsleep: 430,
          ),
        ],
      );
      expect(withExtras, without);
    });
  });

  group('inferPassivePhase — honest null', () {
    test('too few readings → null', () {
      final est = inferPassivePhase(
        temperatures: cleanSeries(lastDayOffset: 6), // 7 readings < 9
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 6),
      );
      expect(est, isNull);
    });

    test('no shift in a flat series → null', () {
      final flat = [
        for (var d = 0; d <= 24; d++) row(d, 36.30 + ((d * 37) % 7 - 3) * 0.01),
      ];
      final est = inferPassivePhase(
        temperatures: flat,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(est, isNull);
    });

    test('a gappy series that cannot form a 6+3 run → null', () {
      // Keep only every third day: never 3 consecutive elevated readings.
      final gappy = [
        for (var d = 0; d <= 30; d++)
          if (d % 3 == 0)
            row(d, 36.30 + (d >= 13 ? 0.35 : 0.0) + ((d * 37) % 7 - 3) * 0.01),
      ];
      final est = inferPassivePhase(
        temperatures: gappy,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 30),
      );
      expect(est, isNull);
    });

    test('no open cycle → null', () {
      final est = inferPassivePhase(
        temperatures: cleanSeries(),
        cycles: const [],
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(est, isNull);
    });

    test('a pregnancy-gap current cycle → null', () {
      final est = inferPassivePhase(
        temperatures: cleanSeries(),
        cycles: [
          Cycle(periodStart: cycleStart, interruptedBy: PregnancyEndKind.birth),
        ],
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(est, isNull);
    });
  });

  group('inferPassivePhase — confidence is monotonic in signal quality', () {
    test('more post-shift readings never lower confidence', () {
      PassiveConfidence at(int lastDay) => inferPassivePhase(
        temperatures: cleanSeries(shiftDayOffset: 13, lastDayOffset: lastDay),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, lastDay),
      )!.confidence;

      final seq = [for (var last = 15; last <= 28; last++) at(last)];
      for (var i = 1; i < seq.length; i++) {
        expect(
          seq[i].index,
          greaterThanOrEqualTo(seq[i - 1].index),
          reason: 'confidence dropped between day ${14 + i} and ${15 + i}',
        );
      }
      // A long, dense post-shift run reads as high.
      expect(seq.last, PassiveConfidence.high);
    });

    test('a denser series is at least as confident as a sparser one', () {
      final dense = inferPassivePhase(
        temperatures: cleanSeries(lastDayOffset: 24),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      )!;
      final sparse = inferPassivePhase(
        temperatures: cleanSeries(
          lastDayOffset: 24,
          drop: {1, 4, 7, 10, 16, 19, 22},
        ),
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      )!;
      expect(
        dense.confidence.index,
        greaterThanOrEqualTo(sparse.confidence.index),
      );
    });
  });

  group('inferPassivePhase — today is respected', () {
    test('a shift in the future relative to today is not yet visible', () {
      final series = cleanSeries(shiftDayOffset: 13, lastDayOffset: 24);
      // Ask on day 10 — before the elevated run exists in-window.
      final early = inferPassivePhase(
        temperatures: series,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 10),
      );
      expect(early, isNull);

      final later = inferPassivePhase(
        temperatures: series,
        cycles: openCycle(),
        prediction: null,
        today: addDays(cycleStart, 24),
      );
      expect(later, isNotNull);
    });
  });
}
