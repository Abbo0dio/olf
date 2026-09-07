import 'dart:math' as math;

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart' show BbtMeasurementKind;
import 'synthetic_history.dart';

/// A deterministic synthetic **passive temperature series** for a
/// [SyntheticHistory] (p8.5) — the wearable-only track the p8.5 inference and
/// `PassiveInformedPredictor` are scored against.
///
/// Everything is pure arithmetic over a **seeded** [math.Random], so the same
/// `(history, seed, params)` always produces a byte-identical list — the
/// backtest stays reproducible in CI. No real user data, no `DateTime.now()`.
///
/// The model, per completed cycle in [history.ovulationByStart]:
///  * a low-phase mean of [lowMeanC] with Gaussian day-to-day noise
///    ([noiseSdC]);
///  * a sustained step of [shiftC] from the day **after** that cycle's true
///    ovulation to the end of the cycle (the classic post-ovulatory rise);
///  * each day independently dropped with probability [missRate] (a wearable
///    the user did not wear that night).
///
/// Rows are returned as `bbt_entries` data with
/// `measurementKind = sleepingWrist` (a passive Apple Watch track) unless
/// [asBasal] is set. Oldest day first.
List<BbtEntry> syntheticPassiveTemperature(
  SyntheticHistory history, {
  int seed = 7,
  double lowMeanC = 36.35,
  double shiftC = 0.40,
  double noiseSdC = 0.06,
  double missRate = 0.08,
  bool asBasal = false,
}) {
  final rng = math.Random(seed);
  final starts = history.periodStarts;
  final stamp = DateTime.utc(2000);
  final kind = asBasal
      ? BbtMeasurementKind.basal
      : BbtMeasurementKind.sleepingWrist;

  final out = <BbtEntry>[];
  for (var i = 0; i < starts.length - 1; i++) {
    final cycleStart = dateOnly(starts[i]);
    final cycleEnd = dateOnly(starts[i + 1]); // exclusive
    final trueOvulation = history.ovulationByStart[starts[i]];
    final riseFrom = trueOvulation == null
        ? null
        : addDays(dateOnly(trueOvulation), 1);

    for (var day = cycleStart; day.isBefore(cycleEnd); day = addDays(day, 1)) {
      if (rng.nextDouble() < missRate) continue;
      final elevated = riseFrom != null && !day.isBefore(riseFrom);
      final value =
          lowMeanC + (elevated ? shiftC : 0.0) + _gaussian(rng, 0, noiseSdC);
      out.add(
        BbtEntry(
          date: day,
          tempCelsius: double.parse(value.toStringAsFixed(3)),
          measurementKind: kind,
          source: 'appleHealth',
          externalId: 'syn-${day.toIso8601String()}',
          sourceDevice: asBasal ? null : 'Apple Watch',
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }
  }
  return out;
}

/// Box–Muller normal sample over a seeded PRNG (reproducible).
double _gaussian(math.Random rng, double mean, double sd) {
  final u1 = 1.0 - rng.nextDouble();
  final u2 = 1.0 - rng.nextDouble();
  final mag = sd * math.sqrt(-2.0 * math.log(u1));
  return mag * math.cos(2 * math.pi * u2) + mean;
}
