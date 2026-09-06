import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'support_resources_content.dart';

/// Copy for TTC mode (p7.3). Plain, non-clinical, **non-prescriptive** — it
/// describes patterns ("some people aim for…"), it never instructs. Every
/// number is framed as relative to the user's own cycle, never as an absolute
/// chance of conceiving.

/// The framing line shown right under the score.
const String ttcScoreFraming =
    'A relative likelihood drawn from your own logged patterns — not a measure '
    'of how likely you are to conceive.';

/// Shown in place of a score when there is not enough history.
const String ttcEmptyStateBody =
    'Once you have a couple of complete cycles logged, this screen will show a '
    'daily fertility estimate and your predicted fertile window. Keep logging '
    'your periods — and basal temperature or cervical mucus if you track them — '
    'and it will fill in.';

/// The fixed disclaimer every TTC screen state carries: not a medical device,
/// and — explicitly — not contraception guidance.
const String ttcModeDisclaimer =
    '${SupportResources.notMedicalDeviceLine} This is not contraception '
    'guidance — do not use these scores to try to avoid pregnancy.';

/// A coarse word for a score, for the headline.
String ttcScoreBandLabel(int score) {
  if (score >= 70) return 'High';
  if (score >= 45) return 'Elevated';
  if (score >= 20) return 'Low';
  return 'Very low';
}

/// e.g. `Elevated · 58 / 100`.
String ttcScoreHeadline(DailyFertilityScore s) =>
    '${ttcScoreBandLabel(s.score)} · ${s.score} / 100';

/// e.g. `Estimated range 42–74`.
String ttcScoreRangeLine(DailyFertilityScore s) =>
    'Estimated range ${s.low}–${s.high}';

/// Redacted `Semantics` label for the score when "Reduce spoken detail" is on —
/// says an estimate exists, not what it is.
const String ttcScoreRedactedLabel = 'Fertility estimate available.';

/// The fertile window as a range, e.g. `Fertile window: 3 Aug 2026 – 9 Aug 2026`.
/// Always a span — TTC mode never shows a single "fertile day".
String ttcFertileWindowLine(DateRange window) =>
    'Fertile window: ${formatRange(window.start, window.end)}';

/// One-line, non-prescriptive timing guidance for [today]'s score.
String ttcGuidance(DailyFertilityScore today) {
  if (today.factors.contains(FertilityFactor.thermalShiftPassed)) {
    return 'Your logged temperature rise suggests ovulation has passed for '
        'this cycle, so fertility is low until your next one.';
  }
  final window = today.fertileWindow;
  if (today.date.isBefore(window.start)) {
    return 'Your estimated fertile days are coming up '
        '(${formatRange(window.start, window.end)}). Some people aim for time '
        'together across that span, more often as it approaches the peak.';
  }
  if (!today.date.isAfter(window.end)) {
    return "You're in your estimated fertile window "
        '(${formatRange(window.start, window.end)}). The days around the peak '
        'tend to matter most.';
  }
  return 'Your estimated fertile window for this cycle has passed. A new one '
      'is estimated after your next period.';
}

/// A plain sentence for each [FertilityFactor], for the "what shaped this"
/// list. Returns `null` for factors with nothing useful to say on their own.
String? ttcFactorExplanation(FertilityFactor factor) => switch (factor) {
  FertilityFactor.predictedWindow =>
    'Based on your predicted fertile window from past cycles.',
  FertilityFactor.fertileMucusToday =>
    'Raised because you logged fertile-quality cervical mucus today.',
  FertilityFactor.fertileMucusRecent =>
    "You've logged fertile-quality cervical mucus this cycle.",
  FertilityFactor.thermalShiftPassed =>
    'Lowered — your basal temperature rise suggests ovulation has already '
        'passed.',
  FertilityFactor.thinHistory =>
    "Wide range — there isn't much cycle history yet.",
  FertilityFactor.irregularHistory =>
    'Wide range — your recent cycles vary a lot, so any single day is '
        'uncertain.',
};

/// A short confidence phrase for the score's band.
String ttcConfidenceLabel(FertilityConfidence c) => switch (c) {
  FertilityConfidence.high => 'Based on a regular, well-logged history.',
  FertilityConfidence.medium => 'A rough estimate — some uncertainty.',
  FertilityConfidence.low => 'A very rough estimate — treat it loosely.',
  FertilityConfidence.none => '',
};

/// Column label for a day in the outlook list. [index] 0 is today.
String ttcDayLabel(DateTime day, int index) =>
    index == 0 ? 'Today' : formatDay(day);
