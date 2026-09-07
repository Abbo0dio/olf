import 'package:meta/meta.dart';

import '../bbt/thermal_shift.dart';
import '../cycle/cycle.dart';
import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart' show BbtMeasurementKind;
import '../prediction/predictor.dart';

/// Which temperature series the inference read (for display / debugging — never
/// a behaviour switch downstream).
enum PassiveSignalTrack {
  /// Waking basal body temperatures (`measurementKind == basal`), from manual
  /// entry or a `basalBodyTemperature` health-platform import.
  basal,

  /// Apple Watch overnight sleeping-wrist temperatures (p8.1a).
  sleepingWrist,
}

/// What the passive temperature signal supports saying about the current cycle.
///
/// Deliberately a **one-sided** read: the only thing a thermal shift confirms is
/// that the post-ovulatory rise has already happened. There is no
/// "you did not ovulate" value and no fertility / conception verdict — that
/// would be a diagnosis this signal cannot make (§6, §9(12)).
enum PassivePhaseRead {
  /// A sustained post-ovulatory temperature rise is confirmed in this cycle, so
  /// ovulation has most likely already passed.
  ovulationLikelyPassed,
}

/// How much to trust a [PassivePhaseEstimate] — a coarse band, not a percentage.
///
/// Monotonic in signal quality: more sustained elevated readings, a clearer rise
/// above the noise threshold, and denser (roughly-daily) logging can only move
/// it up, never down.
enum PassiveConfidence { low, medium, high }

/// A platform-agnostic heart-rate-variability sample. **Accepted but not
/// consumed in p8.5** — the inference is temperature-only for now; HRV is
/// reserved for corroboration in p8.6, and ingesting it from the OS health
/// store (a new `HealthSampleType` + `HealthUnit(ms)` + bridge wiring) is a
/// separate follow-up. Keeping the type here fixes the [inferPassivePhase]
/// signature so that follow-up is purely additive.
@immutable
class PassiveHrvSample {
  const PassiveHrvSample({required this.at, required this.millis});

  /// When the reading was taken (local time; only the calendar day is used).
  final DateTime at;

  /// RMSSD / SDNN in milliseconds — the unit HealthKit and Health Connect both
  /// expose HRV in.
  final double millis;
}

/// A platform-agnostic nightly-sleep sample. Accepted but not consumed in p8.5
/// (see [PassiveHrvSample]).
@immutable
class PassiveSleepSample {
  const PassiveSleepSample({required this.night, required this.minutesAsleep});

  /// The calendar day the sleep is attributed to.
  final DateTime night;

  /// Total minutes asleep that night.
  final double minutesAsleep;
}

/// The inference's answer for one cycle: where the passive temperature signal
/// says the user is, with an explicit [confidence]. `inferPassivePhase` returns
/// `null` rather than a low-confidence guess when the signal is too thin.
@immutable
class PassivePhaseEstimate {
  const PassivePhaseEstimate({
    required this.read,
    required this.estimatedOvulation,
    required this.confidence,
    required this.trackUsed,
    required this.postShiftReadingCount,
    required this.riseCelsius,
  });

  final PassivePhaseRead read;

  /// Best single-day estimate of ovulation (the day before the sustained rise
  /// began). Coarse on purpose — temperature places ovulation only to within a
  /// day or two.
  final DateTime estimatedOvulation;

  final PassiveConfidence confidence;
  final PassiveSignalTrack trackUsed;

  /// How many readings on or after the shift day corroborate the rise.
  final int postShiftReadingCount;

  /// How far the shift-day reading sat above the baseline coverline, in °C.
  final double riseCelsius;

  @override
  bool operator ==(Object other) =>
      other is PassivePhaseEstimate &&
      other.read == read &&
      other.estimatedOvulation == estimatedOvulation &&
      other.confidence == confidence &&
      other.trackUsed == trackUsed &&
      other.postShiftReadingCount == postShiftReadingCount &&
      other.riseCelsius == riseCelsius;

  @override
  int get hashCode => Object.hash(
    read,
    estimatedOvulation,
    confidence,
    trackUsed,
    postShiftReadingCount,
    riseCelsius,
  );

  @override
  String toString() =>
      'PassivePhaseEstimate($read, ovulation~: $estimatedOvulation, '
      '$confidence, track: ${trackUsed.name}, '
      'postShift: $postShiftReadingCount, rise: '
      '${riseCelsius.toStringAsFixed(2)}°C)';
}

/// The fewest readings a track needs before it can be trusted: the "3 over 6"
/// rule's baseline plus elevated run.
const int _minTrackReadings = 9;

/// Estimate where in the current cycle the user is from the **passive
/// temperature history** — notably a temperature-shift confirmation that
/// ovulation has already passed.
///
/// Pure and `today`-injected: no `DateTime.now()`, no Flutter, and the result is
/// a deterministic function of the inputs (all ordering is internal). Returns
/// `null` — an honest "not enough signal" — when there is no open cycle to speak
/// about, when neither temperature track has [_minTrackReadings] readings in the
/// cycle so far, or when no sustained post-ovulatory rise is detectable yet.
///
/// Inputs:
///  * [temperatures] — every `bbt_entries` row available. Split internally into
///    a **basal** track (`measurementKind == basal`, any `source` — manual or a
///    `basalBodyTemperature` import) and a **sleeping-wrist** track (p8.1a). The
///    basal track is used when it has enough readings; otherwise the wrist track
///    is re-typed and used. The two are **never blended inside one
///    baseline/elevated window** — wrist temperature runs cooler and noisier, so
///    mixing scales would corrupt the coverline. See
///    `docs/passive-phase-inference.md`.
///  * [cycles] — the derived cycle history, newest first (as `deriveCycles`
///    returns it). The open cycle ([cycles].first) is the one estimated.
///  * [prediction] — the current [CyclePrediction], accepted so a later revision
///    can cross-check the inferred ovulation against the forecast window; v1
///    does not need it, but the parameter keeps the signature stable.
///  * [hrv] / [sleep] — accepted, **not consumed** in p8.5 (see
///    [PassiveHrvSample]).
///
/// Reuses p7.3's [thermalShift] primitive for the actual shift detection — there
/// is deliberately no second shift detector.
PassivePhaseEstimate? inferPassivePhase({
  required Iterable<BbtEntry> temperatures,
  required List<Cycle> cycles,
  required CyclePrediction? prediction,
  required DateTime today,
  Iterable<PassiveHrvSample> hrv = const [],
  Iterable<PassiveSleepSample> sleep = const [],
}) {
  // Stage 0 — anchor on the open cycle.
  if (cycles.isEmpty) return null;
  final current = cycles.first;
  if (!current.isCurrent || current.isPregnancyGap || current.isLikelyGap) {
    return null;
  }
  final cycleStart = current.periodStart;
  final t = dateOnly(today);
  if (cycleStart.isAfter(t)) return null;

  // Stage 1 — build the two tracks for [cycleStart, today], each as plain
  // `basal` BbtEntry rows so [thermalShift] consumes them directly.
  final inWindow = temperatures.where((e) {
    final d = dateOnly(e.date);
    return !d.isBefore(cycleStart) && !d.isAfter(t);
  });

  final basalTrack = [
    for (final e in inWindow)
      if (e.measurementKind == BbtMeasurementKind.basal) e,
  ];
  final wristTrack = [
    for (final e in inWindow)
      if (e.measurementKind == BbtMeasurementKind.sleepingWrist)
        e.copyWith(measurementKind: BbtMeasurementKind.basal),
  ];

  final PassiveSignalTrack trackUsed;
  final List<BbtEntry> track;
  if (basalTrack.length >= _minTrackReadings) {
    trackUsed = PassiveSignalTrack.basal;
    track = basalTrack;
  } else if (wristTrack.length >= _minTrackReadings) {
    trackUsed = PassiveSignalTrack.sleepingWrist;
    track = wristTrack;
  } else {
    return null;
  }

  // Stage 2 — detect the post-ovulatory shift with the p7.3 primitive.
  // SHORTCUT: `thermalShift` runs the "3 over 6" rule on the reading *sequence*,
  // not on calendar-spaced days (its own documented limitation). A gappy track
  // can therefore confirm a shift off three non-consecutive days. We do not
  // re-implement day-spacing here — instead `density` feeds the confidence band
  // down when logging is sparse. A calendar-aware detector is p8.6+ work.
  final shift = thermalShift(track, cycleStart: cycleStart, today: t);
  if (shift == null) return null;

  // Stage 3 — read + confidence.
  final ordered = [for (final e in track) dateOnly(e.date)]..sort();
  final postShift = ordered.where((d) => !d.isBefore(shift.shiftDate)).length;
  final lastReading = ordered.last;
  final spanDays = daysBetween(cycleStart, lastReading) + 1;
  final density = spanDays <= 0 ? 0.0 : ordered.length / spanDays;
  final riseMargin = shift.riseCelsius - thermalShiftThresholdCelsius;

  return PassivePhaseEstimate(
    read: PassivePhaseRead.ovulationLikelyPassed,
    estimatedOvulation: shift.estimatedOvulation,
    confidence: _confidence(
      postShiftReadingCount: postShift,
      riseMargin: riseMargin,
      density: density,
    ),
    trackUsed: trackUsed,
    postShiftReadingCount: postShift,
    riseCelsius: shift.riseCelsius,
  );
}

/// Coarse confidence band, monotonic in each input: a higher post-shift reading
/// count, a clearer rise above the [thermalShiftThresholdCelsius] noise floor,
/// and denser logging each add a point; the band never falls when any of them
/// grows.
PassiveConfidence _confidence({
  required int postShiftReadingCount,
  required double riseMargin,
  required double density,
}) {
  var score = 0;
  if (postShiftReadingCount >= 3) score++;
  if (postShiftReadingCount >= 6) score++;
  if (riseMargin >= 0.1) score++;
  if (density >= 0.6) score++;

  if (score >= 4) return PassiveConfidence.high;
  if (score >= 2) return PassiveConfidence.medium;
  return PassiveConfidence.low;
}
