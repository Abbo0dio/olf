import 'package:meta/meta.dart';

import '../date_math.dart';

/// An inclusive span of calendar days, `start`..`end` (both ends counted).
///
/// Used wherever the app shows an uncertain date as a window rather than a
/// single false-precise day — the predicted next period, the fertile window.
@immutable
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = dateOnly(start),
      end = dateOnly(end),
      assert(
        !dateOnly(end).isBefore(dateOnly(start)),
        'DateRange end must not be before start',
      );

  final DateTime start;
  final DateTime end;

  /// Whole days covered, inclusive of both ends (a single-day range is 1).
  int get lengthInDays => daysBetween(start, end) + 1;

  /// `true` when [day]'s calendar date falls within the span.
  bool contains(DateTime day) => isWithinRange(day, start, end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($start … $end)';
}
