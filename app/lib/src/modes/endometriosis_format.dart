import 'package:olf_core/olf_core.dart';

import 'support_resources_content.dart';

/// Copy for endometriosis mode (p7.5). Descriptive, gender-neutral,
/// non-diagnostic (phase-07 "No diagnosis, no alarm" + p4.3 sensitive-copy
/// discipline): it describes what you logged and how it lines up with your
/// cycle — never a verdict ("you have endometriosis") and never a directive.

/// The framing note at the top of the screen.
const String endoIntro =
    'Log pain and flares as they happen. Over a few cycles this shows how they '
    'line up with your cycle phase — a description of your own pattern, not a '
    'diagnosis.';

/// Heading over the correlation views.
const String endoAcrossCycleHeading = 'Pain and flares across your cycle';

/// Shown once under the heading.
const String endoNotDiagnosisLine =
    'This describes the days you logged. It cannot tell you whether you have '
    'endometriosis — only a clinician can assess that.';

/// Empty state when nothing is logged yet.
const String endoEmptyState =
    'Nothing logged yet. Add a pain or flare day and, once you have a couple of '
    'cycles recorded, a pattern will show here.';

/// Lower-case phase noun for a sentence ("in your luteal phase").
String endoPhaseNoun(CyclePhaseKind kind) => switch (kind) {
  CyclePhaseKind.menstrual => 'menstrual',
  CyclePhaseKind.follicular => 'follicular',
  CyclePhaseKind.ovulatory => 'ovulatory',
  CyclePhaseKind.luteal => 'luteal',
};

/// The one-line read under a category ("Flares" / "Pain days").
String endoCorrelationLine(String noun, PhaseCorrelation c) {
  if (!c.enoughData) {
    return 'Not enough logged days yet to show how $noun track your cycle. '
        'Keep logging and a pattern will show here.';
  }
  final days = c.totalDays == 1 ? '1 day' : '${c.totalDays} days';
  final most = c.showsUpMostIn;
  if (most == null) {
    return 'Logged on $days. No clear tie to one cycle phase so far.';
  }
  return 'Logged on $days, most often in your ${endoPhaseNoun(most)} phase.';
}

/// Screen-reader form when "Reduce spoken detail" is on — no day counts.
String endoCorrelationLineRedacted(String noun, PhaseCorrelation c) {
  if (!c.enoughData) return 'Not enough logged days yet to show a pattern.';
  final most = c.showsUpMostIn;
  return most == null
      ? 'No clear tie to one cycle phase so far.'
      : 'Runs highest in your ${endoPhaseNoun(most)} phase.';
}

/// Sentence-case label for a body region.
String painRegionLabel(PainRegion region) => switch (region) {
  PainRegion.pelvic => 'Pelvic',
  PainRegion.lowerAbdomen => 'Lower abdomen',
  PainRegion.lowerBack => 'Lower back',
  PainRegion.legs => 'Legs',
  PainRegion.other => 'Other',
};

/// One-line summary of a logged day, e.g. "Moderate · Pelvic · flare".
String painEntrySummary(PainEntry e) {
  final parts = <String>[e.intensity.label];
  if (e.region != null) parts.add(painRegionLabel(e.region!));
  if (e.isFlare) parts.add('flare');
  return parts.join(' · ');
}

/// Redacted `Semantics` form of [painEntrySummary] — that a day is logged, not
/// how bad it was.
const String painEntrySummaryRedacted = 'Pain logged for this day.';

/// The fixed not-a-medical-device line every mode screen carries (§6).
const String endoDisclaimer = SupportResources.notMedicalDeviceLine;
