import 'package:olf_core/olf_core.dart';

import 'support_resources_content.dart';

/// Copy for perimenopause / menopause mode (p7.7). Descriptive, gender-neutral,
/// non-diagnostic (phase-07 "No diagnosis, no alarm" + p4.3 sensitive-copy
/// discipline): it describes what the log shows and states plainly that it is
/// **not** a medical score or a diagnosis.
///
/// The §9(12) hard line: there is deliberately **no** number here — no
/// "Perimenopause Score", no 0–100, no percentage. A short honest sentence
/// beats a fake metric.

/// Perimenopause-relevant symptom names for the timeline. A bundled name list —
/// **not** new storage. The timeline shows a correlation for any of these that
/// the user has logged, plus the user's own (non-built-in) symptoms. Names that
/// are not already in the catalogue simply do not appear until they are logged
/// the normal way (the symptom day sheet).
const List<String> kPerimenopauseSymptomNames = <String>[
  'Hot flashes',
  'Night sweats',
  'Trouble sleeping',
  'Low mood',
  'Anxiety',
  'Fatigue',
  'Headache',
  'Cycle changes',
  'Brain fog',
  'Joint aches',
];

/// The framing note at the top of the mode screen and — softened — on the
/// cycle card: longer, more variable and skipped cycles are the *expected*
/// signal here, not errors.
const String perimenopauseExpectedSignalNote =
    'This mode expects your cycles to get longer, more variable, and to skip. '
    'Those changes are shown here as the normal pattern for this stage, not '
    'flagged as problems.';

/// Heading over the transition read.
const String perimenopauseTransitionHeading = 'Where things might be';

/// One-line lede under that heading — sets the not-a-score expectation.
const String perimenopauseTransitionLede =
    'A plain read of what your logged cycles show. It is not a score and not a '
    'diagnosis — only a clinician can assess the transition.';

/// The descriptive transition read for a [PerimenopauseStageHint].
String perimenopauseStageRead(PerimenopauseStageHint hint) => switch (hint) {
  PerimenopauseStageHint.notEnoughData =>
    'Not enough logged cycle history yet to say how things are trending. Keep '
        'logging and a read will show here.',
  PerimenopauseStageHint.cyclesLookRegular =>
    'Your recent cycles look about as regular as before — no clear change in '
        'how much they vary.',
  PerimenopauseStageHint.cyclesBecomingLessRegular =>
    'Your recent cycles are becoming less regular — the spread in cycle length '
        'is widening compared with earlier.',
  PerimenopauseStageHint.longGapsAppearing =>
    'There are long gaps between your recent cycles. Longer and skipped cycles '
        'are common in the perimenopause transition.',
  PerimenopauseStageHint.twelveMonthsPlus =>
    'It has been 12 or more months since your last logged period. That is the '
        'common definition of menopause — this is information from your log, '
        'not a diagnosis.',
};

/// Screen-reader form when "Reduce spoken detail" is on — no figures.
String perimenopauseStageReadRedacted(PerimenopauseStageHint hint) =>
    switch (hint) {
      PerimenopauseStageHint.notEnoughData =>
        'Not enough logged cycle history yet.',
      PerimenopauseStageHint.cyclesLookRegular =>
        'Recent cycles look about as regular as before.',
      PerimenopauseStageHint.cyclesBecomingLessRegular =>
        'Recent cycles are becoming less regular.',
      PerimenopauseStageHint.longGapsAppearing =>
        'There are long gaps between recent cycles.',
      PerimenopauseStageHint.twelveMonthsPlus =>
        'Twelve or more months since the last logged period.',
    };

/// The factual "12 months" line, shown whenever
/// [PerimenopauseTransitionRead.twelveMonthsSinceLastPeriod] is set. Stated as
/// information, with the disclaimer alongside.
String perimenopauseTwelveMonthLine(int daysSinceLastPeriod) {
  final months = daysSinceLastPeriod ~/ 30;
  return 'Your last logged period was about $months months ago. Twelve months '
      'without a period is the common definition of menopause. This is a fact '
      'from your log — it is not a diagnosis, and only a clinician can confirm '
      'it.';
}

/// Heading over the symptom timeline.
const String perimenopauseTimelineHeading = 'Symptoms across your cycle';

/// Lede under that heading.
const String perimenopauseTimelineLede =
    'How the perimenopause-related things you log line up with your cycle '
    'phase. It describes your log — it is not a symptom check.';

/// Empty state for the timeline.
const String perimenopauseTimelineEmpty =
    'Log perimenopause-related symptoms — hot flashes, sleep, mood, cycle '
    'changes — over a few cycles and this will show how they line up with '
    'cycle phase.';

/// The one-line read under a symptom's name in the timeline.
String perimenopauseCorrelationLine(PhaseCorrelation c) {
  if (!c.enoughData) {
    return 'Not enough logged days yet to show how this tracks your cycle.';
  }
  final days = c.totalDays == 1 ? '1 day' : '${c.totalDays} days';
  final most = c.showsUpMostIn;
  if (most == null) {
    return 'Logged on $days. No clear tie to one cycle phase so far.';
  }
  return 'Logged on $days, most often in your ${_phaseNoun(most)} phase.';
}

/// Screen-reader form with "Reduce spoken detail" on — no day counts.
String perimenopauseCorrelationLineRedacted(PhaseCorrelation c) {
  if (!c.enoughData) return 'Not enough logged days yet to show a pattern.';
  final most = c.showsUpMostIn;
  return most == null
      ? 'No clear tie to one cycle phase so far.'
      : 'Shows up most in your ${_phaseNoun(most)} phase.';
}

String _phaseNoun(CyclePhaseKind kind) => switch (kind) {
  CyclePhaseKind.menstrual => 'menstrual',
  CyclePhaseKind.follicular => 'follicular',
  CyclePhaseKind.ovulatory => 'ovulatory',
  CyclePhaseKind.luteal => 'luteal',
};

/// Added to the prediction card while perimenopause mode is on (and the
/// forecast is still shown — see [perimenopauseForecastSuppressedNote] for when
/// it is not).
const String perimenopauseWiderIntervalNote =
    'Cycle length gets more variable through the transition, so treat the date '
    'range as wide and the estimate as loose.';

/// Replaces the forecast card while perimenopause mode is on and history shows
/// a long gap / 12+ months since the last period — a forecast built on
/// pre-gap cycles would assert more than the data supports.
const String perimenopauseForecastSuppressedNote =
    'The next-period estimate is paused while there is a long gap in your '
    'cycles. Longer and skipped cycles are expected in this stage; log your '
    'next period and the estimate will pick back up.';

/// Replaces the default "a period may not have been logged" gap line while
/// perimenopause mode is on.
const String perimenopauseSoftenedGapLine =
    'A long stretch is set aside from the averages. Longer and skipped cycles '
    'are common in the perimenopause transition.';

/// The fixed not-a-medical-device line every mode screen carries (§6).
const String perimenopauseDisclaimer = SupportResources.notMedicalDeviceLine;
