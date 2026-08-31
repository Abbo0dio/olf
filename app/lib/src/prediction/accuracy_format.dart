/// User-facing copy for the private prediction-accuracy screen (p3.5).
///
/// Every string here is a named `const` so `accuracy_copy_test.dart` can hold
/// the line: non-alarming, gender-neutral, and — importantly — the screen makes
/// **no accuracy claim of its own**. It shows the user *their* number, worked
/// out on device from *their* logged history, with the sample size next to it.
library;

/// Settings row.
const String accuracySettingsTitle = 'Prediction accuracy';
const String accuracySettingsSubtitle =
    'See how close past estimates were, from your own logged history.';

/// Screen.
const String accuracyScreenTitle = 'Prediction accuracy';

const String accuracyIntro =
    'olf replayed every past estimate against the period that actually '
    'followed. Here is how close it came for you.';

/// The privacy line — must name the device and say nothing is sent.
const String accuracyPrivacyNote =
    'These numbers are worked out on this device from your own logged history. '
    'Nothing is sent anywhere.';

/// Shown instead of any number when there is too little history.
const String accuracyThinHistory =
    "There isn't enough logged history to measure yet. Keep logging your "
    'periods and check back.';

const String accuracyWorkingLabel = 'Working through your logged history…';

const String accuracyErrorLabel = 'Could not work this out right now.';

/// Metric labels.
const String accuracyTypicalMissLabel = 'Typical miss';
const String accuracyTypicalMissHint =
    'Average days between the estimate and '
    'the real start.';
const String accuracyMedianMissLabel = 'Middle miss';
const String accuracyMedianMissHint =
    'Half of the estimates were at least '
    'this close.';
const String accuracyInRangeLabel = 'Started inside the estimated range';
const String accuracyTrendLabel = 'Miss per past estimate';

/// "Checked against N past periods" — the sample size, always shown with a
/// number so no metric is read without its base.
String accuracySampleSize(int scoredPoints) => scoredPoints == 1
    ? 'Checked against 1 past period'
    : 'Checked against $scoredPoints past periods';

/// A miss in whole days, phrased loosely. `null` → an em dash.
String accuracyDays(double? days) {
  if (days == null) return '—';
  final rounded = days.round();
  if (rounded <= 0) return 'under a day';
  return rounded == 1 ? 'about 1 day' : 'about $rounded days';
}

/// Coverage as a plain percentage. `null` → an em dash.
String accuracyPercent(double? fraction) =>
    fraction == null ? '—' : '${(fraction * 100).round()}%';

/// a11y summary for the sparkline.
String accuracyTrendSemantics(List<int> perDecisionAbsErrorDays) {
  if (perDecisionAbsErrorDays.isEmpty) return accuracyTrendLabel;
  final lo = perDecisionAbsErrorDays.reduce((a, b) => a < b ? a : b);
  final hi = perDecisionAbsErrorDays.reduce((a, b) => a > b ? a : b);
  return '$accuracyTrendLabel, from $lo to $hi days across '
      '${perDecisionAbsErrorDays.length} past estimates, oldest first.';
}
