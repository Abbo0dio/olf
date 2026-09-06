import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'support_resources_content.dart';

/// Copy for the pregnancy-mode week view (p7.2a). Plain, non-clinical; the
/// week-by-week notes themselves live in `core`'s `pregnancy_week_notes.dart`.

/// e.g. `Week 24, day 3`.
String gestationalAgeHeadline(GestationalAge ga) {
  final day = ga.daysIntoWeek;
  final dayPart = day == 1 ? '1 day' : '$day days';
  return 'Week ${ga.completedWeeks}, $dayPart';
}

/// Redacted headline for "Reduce spoken detail" — no week number.
const String gestationalAgeHeadlineRedacted = "You're tracking a pregnancy.";

/// e.g. `Second trimester`.
String trimesterLabel(PregnancyTrimester trimester) => switch (trimester) {
  PregnancyTrimester.first => 'First trimester',
  PregnancyTrimester.second => 'Second trimester',
  PregnancyTrimester.third => 'Third trimester',
};

/// e.g. `Estimated due date around 8 Oct 2026.`
String estimatedDueDateLine(PregnancyStartReference reference) =>
    'Estimated due date around ${formatDay(reference.estimatedDueDate)}.';

/// Standalone label for a reference kind, for the picker and the "based on…"
/// line under the week view.
String referenceKindLabel(PregnancyReferenceKind kind) => switch (kind) {
  PregnancyReferenceKind.lastMenstrualPeriod => 'First day of last period',
  PregnancyReferenceKind.dueDate => 'Estimated due date',
  PregnancyReferenceKind.conceptionDate => 'Conception date',
};

/// e.g. `Based on the first day of your last period, 1 Jan 2026.`
String referenceSummaryLine(PregnancyStartReference reference) {
  final basis = switch (reference.kind) {
    PregnancyReferenceKind.lastMenstrualPeriod =>
      'the first day of your last period',
    PregnancyReferenceKind.dueDate => 'your estimated due date',
    PregnancyReferenceKind.conceptionDate => 'your conception date',
  };
  return 'Based on $basis, ${formatDay(reference.date)}.';
}

/// One-line intro shown above the week note.
const String pregnancyWeekViewIntro =
    'A rough guide to what is often happening around this week. Every pregnancy '
    'is different.';

/// Shown when a start reference has not been entered yet.
const String pregnancyNeedsReferenceBody =
    'Add a date to see where you are by week. You can use the first day of your '
    'last period, an estimated due date, or a conception date — whichever you '
    'know.';

/// Shown when the entered reference is in the future (no gestational age yet).
const String pregnancyReferenceInFutureBody =
    'The date you entered is in the future, so there is no week to show yet. '
    'Change it if that was a slip.';

/// The not-a-medical-device line every mode screen carries (§6).
const String pregnancyModeDisclaimer = SupportResources.notMedicalDeviceLine;
