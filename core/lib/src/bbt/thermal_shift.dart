import 'package:meta/meta.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart' show BbtMeasurementKind;

/// How far above the low-phase baseline a reading must sit to count as part of
/// the post-ovulatory thermal shift. The classic fertility-awareness "3 over 6"
/// rule uses ~0.2 °C — a rise smaller than that is within normal night-to-night
/// noise.
const double thermalShiftThresholdCelsius = 0.2;

/// Readings in the low ("follicular") phase that form the baseline, and the
/// number of consecutive elevated readings that confirm the shift.
const int _baselineReadings = 6;
const int _elevatedReadings = 3;

/// A confirmed post-ovulatory temperature rise within one cycle.
///
/// Basal body temperature steps up by a few tenths of a degree after ovulation
/// (progesterone) and stays up until the next period. Detecting that step is a
/// *retrospective* confirmation that ovulation has already happened — it never
/// predicts the fertile window ahead of time.
@immutable
class ThermalShift {
  const ThermalShift({
    required this.shiftDate,
    required this.estimatedOvulation,
    required this.riseCelsius,
  });

  /// The first day of the sustained rise (the first of the elevated readings).
  final DateTime shiftDate;

  /// Best single-day estimate of ovulation: the day before [shiftDate]. Coarse
  /// on purpose — the temperature method places ovulation only to within a day
  /// or two.
  final DateTime estimatedOvulation;

  /// How far [shiftDate]'s reading sat above the baseline coverline, in °C.
  final double riseCelsius;

  @override
  bool operator ==(Object other) =>
      other is ThermalShift &&
      other.shiftDate == shiftDate &&
      other.estimatedOvulation == estimatedOvulation &&
      other.riseCelsius == riseCelsius;

  @override
  int get hashCode => Object.hash(shiftDate, estimatedOvulation, riseCelsius);

  @override
  String toString() =>
      'ThermalShift(shift: $shiftDate, ovulation~: $estimatedOvulation, '
      'rise: ${riseCelsius.toStringAsFixed(2)}°C)';
}

/// Detect the post-ovulatory thermal shift in [entries] for the current cycle,
/// or `null` when there is no confirmed rise yet.
///
/// Only readings from [cycleStart] through [today] (inclusive) are considered,
/// ordered by date. The "3 over 6" rule: take each run of [_elevatedReadings]
/// consecutive readings, compare them against the coverline (the maximum of the
/// [_baselineReadings] readings immediately before them); if all three sit at
/// least [thermalShiftThresholdCelsius] above that coverline, the first of the
/// three is the shift day. The **earliest** such run in the cycle wins.
///
/// [today] is injected — there is no `DateTime.now()` here, so a scan over a
/// fixed history is reproducible.
///
// SHORTCUT: operates on the sequence of logged readings, not calendar-spaced
// days — a multi-day gap in logging can place the coverline on stale data and
// mistime the shift. Ceiling: fine for roughly-daily logging (the norm for
// someone charting BBT to conceive). Upgrade path: require the baseline and
// elevated readings to fall within a bounded date span, or interpolate missing
// days, before trusting the run.
ThermalShift? thermalShift(
  Iterable<BbtEntry> entries, {
  required DateTime cycleStart,
  required DateTime today,
}) {
  final start = dateOnly(cycleStart);
  final t = dateOnly(today);

  // p8.1a: only basal body temperatures form a thermal shift. A passive Apple
  // Watch sleeping-wrist reading shares the `bbt_entries` day slot but measures
  // something else, so it is excluded here — a mixed-kind history produces the
  // identical shift to the same history with the wrist rows removed.
  final readings =
      entries
          .where((e) => e.measurementKind == BbtMeasurementKind.basal)
          .map((e) => (date: dateOnly(e.date), celsius: e.tempCelsius))
          .where((r) => !r.date.isBefore(start) && !r.date.isAfter(t))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  if (readings.length < _baselineReadings + _elevatedReadings) return null;

  for (
    var i = _baselineReadings;
    i + _elevatedReadings <= readings.length;
    i++
  ) {
    final baseline = readings.sublist(i - _baselineReadings, i);
    final coverline = baseline
        .map((r) => r.celsius)
        .reduce((a, b) => a > b ? a : b);

    final elevated = readings.sublist(i, i + _elevatedReadings);
    final allClear = elevated.every(
      (r) => r.celsius >= coverline + thermalShiftThresholdCelsius,
    );
    if (!allClear) continue;

    final shiftDate = elevated.first.date;
    return ThermalShift(
      shiftDate: shiftDate,
      estimatedOvulation: addDays(shiftDate, -1),
      riseCelsius: elevated.first.celsius - coverline,
    );
  }

  return null;
}
