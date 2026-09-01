import 'dart:math' as math;

/// How many days back [learnPreferredHour] looks for logging activity.
const int kPreferredHourRecentWindow = 30;

/// The fewest logging events inside the window before [learnPreferredHour] will
/// commit to an hour. Below this it returns `null` and callers fall back to the
/// category's stored time (or the 09:00 default).
const int kPreferredHourMinSamples = 8;

/// How many recent timestamps a `LoggingActivityRepository` hands back — well
/// above what [kPreferredHourRecentWindow] days of normal logging produces, so
/// the learning input is never silently truncated.
const int kPreferredHourQueryLimit = 200;

/// The hour of day (`0`–`23`) the user tends to log at, learned from
/// [logTimestamps], or `null` when there is not enough recent history to be
/// useful.
///
/// Pure and deterministic. No `DateTime.now()` — callers pass [now]. No time
/// zones: it reads each timestamp's wall-clock [DateTime.hour] only, so it is
/// DST-agnostic, exactly like `nextFireTime` / `nextOccurrence`.
///
///  * Timestamps older than [recentWindow] days before [now] (day-granular
///    cut-off) are ignored.
///  * Fewer than [minSamples] left ⇒ `null`.
///  * Otherwise the **circular mean** of the sample hours: each hour is a point
///    on a 24-point clock, the mean direction is taken and mapped back to
///    `0`–`23`. Circular so 23:00 and 01:00 average to midnight, not to noon.
///  * If the samples have no mean direction at all (e.g. two exactly opposite
///    clusters like 08:00 / 20:00), there is no "circular middle", so it falls
///    back to the plain arithmetic-mean hour — still a reasonable "between".
int? learnPreferredHour({
  required List<DateTime> logTimestamps,
  required DateTime now,
  int recentWindow = kPreferredHourRecentWindow,
  int minSamples = kPreferredHourMinSamples,
}) {
  final cutoff = DateTime(now.year, now.month, now.day - recentWindow);
  final hours = <int>[
    for (final ts in logTimestamps)
      if (!ts.isBefore(cutoff)) ts.hour,
  ];
  if (hours.length < minSamples) return null;

  var x = 0.0;
  var y = 0.0;
  for (final h in hours) {
    final angle = 2 * math.pi * h / 24;
    x += math.cos(angle);
    y += math.sin(angle);
  }

  // No resultant vector — antipodal clusters cancel out. Circular mean is
  // undefined here, so use the arithmetic mean instead.
  if (x.abs() < 1e-9 && y.abs() < 1e-9) {
    final sum = hours.reduce((a, b) => a + b);
    return (sum / hours.length).round() % 24;
  }

  var mean = math.atan2(y, x) / (2 * math.pi) * 24;
  if (mean < 0) mean += 24;
  return mean.round() % 24;
}
