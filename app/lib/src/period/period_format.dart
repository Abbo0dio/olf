import 'package:olf_core/olf_core.dart';

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// e.g. `3 Aug 2026`.
String formatDay(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/// e.g. `August 2026`.
String formatMonthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// A period's date range as one human phrase.
String formatRange(DateTime start, DateTime? end) {
  final s = dateOnly(start);
  if (end == null) return 'From ${formatDay(s)}';
  final e = dateOnly(end);
  if (e == s) return formatDay(s);
  return '${formatDay(s)} – ${formatDay(e)}';
}

/// A period's length in whole days, inclusive. Open-ended periods are counted
/// up to [today] and marked "so far".
String formatLength(DateTime start, DateTime? end, DateTime today) {
  final last = end ?? today;
  final days = daysBetween(start, last) + 1;
  if (end == null) return days == 1 ? '1 day so far' : '$days days so far';
  return days == 1 ? '1 day' : '$days days';
}
