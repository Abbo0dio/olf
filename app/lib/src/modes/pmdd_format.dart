import 'package:olf_core/olf_core.dart';

import 'support_resources_content.dart';

/// Copy for PMDD mode (p7.6). Descriptive, gender-neutral and non-diagnostic
/// (phase-07 "No diagnosis, no alarm" + p4.3 sensitive-copy discipline): it
/// describes the days you rated and how they line up with your cycle. It is
/// **never** a DRSP-style score, a threshold, or a verdict ("you have PMDD" /
/// "you likely have PMDD"). A content test locks this file.

/// The framing note at the top of the screen.
const String pmddIntro =
    'Rate a few things each day. Over a couple of cycles this shows how your '
    'ratings line up with your cycle phase — a description of your own pattern, '
    'not a score and not a diagnosis.';

/// Heading over the overlay.
const String pmddAcrossCycleHeading = 'Your ratings across your cycle';

/// Shown once under the heading.
const String pmddNotDiagnosisLine =
    'This describes the days you rated. It is not a PMDD test and cannot tell '
    'you whether you have PMDD — only a clinician can assess that.';

/// Empty state when nothing is rated yet.
const String pmddEmptyState =
    'Nothing rated yet. Rate today and, once you have a couple of cycles '
    'recorded, a pattern will show here.';

/// The label on the button that opens the daily rating sheet.
String pmddRateButtonLabel({required bool ratedToday}) =>
    ratedToday ? "Edit today's rating" : 'Rate today';

/// Lower-case phase noun for a sentence.
String pmddPhaseNoun(CyclePhaseKind kind) => switch (kind) {
  CyclePhaseKind.menstrual => 'menstrual',
  CyclePhaseKind.follicular => 'follicular',
  CyclePhaseKind.ovulatory => 'ovulatory',
  CyclePhaseKind.luteal => 'luteal',
};

/// The descriptive luteal-vs-follicular sentence — the only "read" the screen
/// shows. No number, no threshold, no verdict.
String pmddLutealSummary(PmddLutealRead read) => switch (read) {
  PmddLutealRead.notEnoughData =>
    'Not enough rated days across enough cycles yet to compare your luteal '
        'phase with the rest of your cycle. Keep rating and this will fill in.',
  PmddLutealRead.noClearLutealPattern =>
    'So far your higher ratings do not line up more with your luteal phase — '
        'the roughly two weeks before your period — than with the rest of your '
        'cycle.',
  PmddLutealRead.runsHigherInLuteal =>
    'So far your higher ratings show up more in your luteal phase — the '
        'roughly two weeks before your period — than earlier in your cycle. '
        'That is a description of your log, not a diagnosis.',
};

/// Screen-reader form when "Reduce spoken detail" is on — same shape, no lead-in
/// about counts (there are none here) and the same non-diagnostic wording.
String pmddLutealSummaryRedacted(PmddLutealRead read) => switch (read) {
  PmddLutealRead.notEnoughData =>
    'Not enough rated days yet to show a pattern.',
  PmddLutealRead.noClearLutealPattern =>
    'No clear tie between your higher ratings and your luteal phase so far.',
  PmddLutealRead.runsHigherInLuteal =>
    'Your higher ratings run higher in your luteal phase so far.',
};

/// One-line summary of the day's rating for the screen, e.g.
/// "Today: rated · highest was Moderate". `none` across the board reads as
/// "Today: rated · nothing notable".
String pmddDaySummary(Map<PmddSymptom, SymptomSeverity> items) {
  if (items.isEmpty) return 'Today: not rated yet';
  var peak = SymptomSeverity.none;
  for (final s in items.values) {
    if (s.rank > peak.rank) peak = s;
  }
  return peak == SymptomSeverity.none
      ? 'Today: rated · nothing notable'
      : 'Today: rated · highest was ${peak.label}';
}

/// Redacted `Semantics` form of [pmddDaySummary] — that the day is rated, not
/// how high.
const String pmddDaySummaryRedacted = 'You rated today.';

/// The heading and helper text for the daily rating sheet.
const String pmddSheetTitle = 'Rate today';
const String pmddSheetIntro =
    'Where each one sits today. Leave it on "None" if it is not a thing for you '
    'today — that still counts as rated.';

/// The fixed not-a-medical-device line every mode screen carries (§6).
const String pmddDisclaimer = SupportResources.notMedicalDeviceLine;
