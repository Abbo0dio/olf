import '../cycle/cycle.dart';
import '../date_math.dart';
import '../db/app_database.dart';

/// One plotted basal temperature: its 1-based day within the cycle, the calendar
/// date, and the reading in °C.
class BbtChartPoint {
  const BbtChartPoint({
    required this.cycleDay,
    required this.date,
    required this.celsius,
  });

  /// Day 1 is [Cycle.periodStart]; day 2 the next calendar day, and so on.
  final int cycleDay;
  final DateTime date;
  final double celsius;

  @override
  bool operator ==(Object other) =>
      other is BbtChartPoint &&
      other.cycleDay == cycleDay &&
      other.date == date &&
      other.celsius == celsius;

  @override
  int get hashCode => Object.hash(cycleDay, date, celsius);
}

/// The BBT points that fall inside [cycle], ordered by day.
///
/// A reading is in the cycle if its date is on or after [Cycle.periodStart] and
/// (for a completed cycle) strictly before [Cycle.nextPeriodStart]. Readings
/// outside that span are dropped — each cycle charts only its own data.
List<BbtChartPoint> bbtChartForCycle(Cycle cycle, Iterable<BbtEntry> entries) {
  final start = dateOnly(cycle.periodStart);
  final end = cycle.nextPeriodStart; // exclusive; null while current

  final points = <BbtChartPoint>[];
  for (final e in entries) {
    final day = dateOnly(e.date);
    if (day.isBefore(start)) continue;
    if (end != null && !day.isBefore(dateOnly(end))) continue;
    points.add(
      BbtChartPoint(
        cycleDay: daysBetween(start, day) + 1,
        date: day,
        celsius: e.tempCelsius,
      ),
    );
  }
  points.sort((a, b) => a.cycleDay.compareTo(b.cycleDay));
  return points;
}
