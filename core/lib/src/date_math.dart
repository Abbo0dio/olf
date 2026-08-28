/// Calendar-day arithmetic used across the cycle engine.
///
/// All functions operate on **whole calendar days in local time** — the
/// time-of-day component of a [DateTime] is ignored. This keeps "Day N of your
/// cycle" stable regardless of what time of day an event was logged.
library;

/// The date [d] with its time-of-day stripped (midnight, local time).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] (local time), ignoring time-of-day.
///
/// Positive when [to] is after [from], negative when before, zero on the same
/// calendar day. DST-safe: the difference is computed from UTC-normalised
/// midnights so a 23- or 25-hour civil day still counts as one day.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// 1-based day number of [now] counting [start] as "Day 1".
///
/// Used for the home-screen "Day N" readout. Returns 1 on the start date, 2 the
/// next calendar day, and so on. Days before [start] return zero or negative
/// values (caller decides how to present a future start date).
int dayCountSince(DateTime start, DateTime now) => daysBetween(start, now) + 1;

/// `true` when [day] falls within the inclusive range \[[start], [end]\].
///
/// A `null` [end] means the range is open — every day on or after [start] is
/// inside it. All three are compared as calendar dates.
bool isWithinRange(DateTime day, DateTime start, DateTime? end) {
  final d = dateOnly(day);
  final s = dateOnly(start);
  if (d.isBefore(s)) return false;
  if (end == null) return true;
  return !d.isAfter(dateOnly(end));
}

/// Midnight on the first day of [d]'s month (local time).
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// Midnight on the last day of [d]'s month (local time).
DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// Number of days in [d]'s month.
int daysInMonth(DateTime d) => lastOfMonth(d).day;

/// [d]'s month shifted by [delta] whole months (negative goes back), anchored
/// to the first of the month so it never lands on an impossible date.
DateTime addMonths(DateTime d, int delta) =>
    DateTime(d.year, d.month + delta, 1);
