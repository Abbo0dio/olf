import 'package:olf_core/olf_core.dart';

import 'support_resources_content.dart';

/// Copy for PCOS mode (p7.4). Descriptive, gender-neutral, non-diagnostic
/// (phase-07 "No diagnosis, no alarm" + p4.3 sensitive-copy discipline): it
/// describes what the user logged, never a verdict and never a directive like
/// "ask your doctor about PCOS" (§9(12), the Flo anti-pattern).

/// Lower-case phase noun for a sentence ("in your luteal phase").
String pcosPhaseNoun(CyclePhaseKind kind) => switch (kind) {
  CyclePhaseKind.menstrual => 'menstrual',
  CyclePhaseKind.follicular => 'follicular',
  CyclePhaseKind.ovulatory => 'ovulatory',
  CyclePhaseKind.luteal => 'luteal',
};

/// The one-line read under a symptom's name in the correlation list.
String pcosCorrelationLine(PhaseCorrelation c) {
  if (!c.enoughData) {
    return 'Not enough logged days yet to show how this tracks your cycle. '
        'Keep logging and a pattern will show here.';
  }
  final days = c.totalDays == 1 ? '1 day' : '${c.totalDays} days';
  final most = c.showsUpMostIn;
  if (most == null) {
    return 'Logged on $days. No clear tie to one cycle phase so far.';
  }
  return 'Logged on $days, most often in your ${pcosPhaseNoun(most)} phase.';
}

/// Screen-reader form when "Reduce spoken detail" is on — no day counts.
String pcosCorrelationLineRedacted(PhaseCorrelation c) {
  if (!c.enoughData) return 'Not enough logged days yet to show a pattern.';
  final most = c.showsUpMostIn;
  return most == null
      ? 'No clear tie to one cycle phase so far.'
      : 'Shows up most in your ${pcosPhaseNoun(most)} phase.';
}

/// The framing note at the top of the PCOS screen and — softened — on the cycle
/// card: long and variable cycles are expected here, not errors.
const String pcosIrregularCycleNote =
    'This mode expects long or variable cycles. Gaps and swings in cycle '
    'length are shown as normal here, not flagged as problems.';

/// Added to the prediction card while PCOS mode is on.
const String pcosWiderIntervalNote =
    'Cycle length varies more with PCOS, so treat the date range as wide and '
    'the estimate as loose.';

/// Replaces the default "a period may not have been logged" gap line while
/// PCOS mode is on.
const String pcosSoftenedGapLine =
    'A long stretch is set aside from the averages. Long gaps between periods '
    'are common with PCOS.';

/// Shown once near the correlation views: this is not a symptom checker.
const String pcosNotSymptomCheckerLine =
    'This shows patterns in what you logged. It is not a symptom check, and it '
    'cannot tell you whether you have PCOS — only a clinician can assess that.';

/// The fixed not-a-medical-device line every mode screen carries (§6).
const String pcosDisclaimer = SupportResources.notMedicalDeviceLine;
