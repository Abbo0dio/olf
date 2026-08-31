import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';

const _months = [
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

/// A calendar-day window as one compact phrase:
/// `12–17 Aug 2026` · `29 Jul – 3 Aug 2026` · `28 Dec 2026 – 2 Jan 2027`.
String formatDateRange(DateRange r) {
  final s = r.start;
  final e = r.end;
  if (s.year == e.year && s.month == e.month) {
    return '${s.day}–${e.day} ${_months[s.month - 1]} ${s.year}';
  }
  if (s.year == e.year) {
    return '${s.day} ${_months[s.month - 1]} – '
        '${e.day} ${_months[e.month - 1]} ${s.year}';
  }
  return '${formatDay(s)} – ${formatDay(e)}';
}

/// Short badge text for how much to trust the estimate.
String confidenceLabel(PredictionConfidence c) => switch (c) {
  PredictionConfidence.low => 'Rough estimate',
  PredictionConfidence.medium => 'Fair estimate',
  PredictionConfidence.high => 'Confident estimate',
};

/// One-sentence note spelling out the uncertainty behind [prediction].
String confidenceNote(CyclePrediction prediction) {
  final n = prediction.basedOnCycles;
  final cycles = n == 1 ? '1 cycle' : '$n cycles';
  return switch (prediction.confidence) {
    PredictionConfidence.high =>
      'Based on your last $cycles, which have been '
          'fairly regular.',
    PredictionConfidence.medium =>
      'Based on your last $cycles — your timing '
          'varies a little, so this is approximate.',
    PredictionConfidence.low =>
      n <= 1
          ? 'Based on just $cycles so far. It will sharpen as you log more.'
          : 'Based on $cycles that vary a fair bit, so treat this loosely.',
  };
}

/// Headline for the late-period check-in. Never names a rolled-forward date.
String overdueHeadline(int daysPastExpected) => daysPastExpected <= 1
    ? 'Your period is about a day later than usual'
    : 'Your period is $daysPastExpected days later than usual';

/// Body copy for the late-period check-in — reassuring, neutral, and clear
/// that logging is what moves things forward.
const String overdueBody =
    "Cycles shift for all sorts of reasons, so this on its own isn't a "
    'concern. Log the start when it arrives and the estimate updates.';

/// Button label for dismissing the transient "your update was applied" note
/// (p3.3). The note's body text comes entirely from `PredictionDelta.reasons`.
const String correctionNoticeDismissLabel = 'Dismiss';
