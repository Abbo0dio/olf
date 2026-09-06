import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'support_resources_content.dart';

/// Lower-case noun for a sentence ("since your birth"), distinct from
/// [pregnancyEndKindLabel] which is a capitalised standalone label.
String postpartumEventNoun(PregnancyEndKind kind) => switch (kind) {
  PregnancyEndKind.loss => 'loss',
  PregnancyEndKind.birth => 'birth',
};

/// One-line headline for the postpartum cycle-return view.
String postpartumHeadline(PostpartumCycleReturn r) {
  final noun = postpartumEventNoun(r.eventKind);
  final days = r.daysSinceEvent;
  final since = days == 1 ? "It's been 1 day" : "It's been $days days";
  return '$since since your $noun on ${formatDay(r.eventDate)}.';
}

/// Redacted headline for "Reduce spoken detail" — no day count.
String postpartumHeadlineRedacted(PostpartumCycleReturn r) =>
    'You recorded a ${postpartumEventNoun(r.eventKind)}. '
    'olf is tracking your cycle coming back.';

/// The body paragraph, chosen by how settled the cycle looks.
String postpartumStatusBody(PostpartumCycleReturn r) {
  switch (r.settling) {
    case PostpartumSettling.awaitingFirstPeriod:
      return 'No period logged since then. That is normal — it can take weeks '
          'or many months. Log a period start when it returns and olf will '
          'start tracking how your cycles settle.';
    case PostpartumSettling.firstCycleLogged:
      final on = r.firstPeriodDate == null
          ? ''
          : ' on ${formatDay(r.firstPeriodDate!)}';
      return 'Your first period back was$on. One cycle is not enough to say '
          'whether things are settling yet — keep logging and a pattern will '
          'show here.';
    case PostpartumSettling.settling:
      final typical = r.postEventCycleStats.typicalCycleLength;
      final tail = typical == null
          ? ''
          : ' Your cycles since then have run around $typical days.';
      return 'Across ${r.postEventCycleCount} cycles since your '
          '${postpartumEventNoun(r.eventKind)}, cycle lengths are staying '
          'within a normal range — they look like they are settling.$tail';
    case PostpartumSettling.stillVariable:
      final lo = r.postEventCycleStats.shortestCycleLength;
      final hi = r.postEventCycleStats.longestCycleLength;
      final range = (lo == null || hi == null)
          ? ''
          : ' Recent cycles have ranged from $lo to $hi days.';
      return 'Across ${r.postEventCycleCount} cycles since your '
          '${postpartumEventNoun(r.eventKind)}, cycle lengths are still '
          'varying quite a bit. That is common for a while.$range';
  }
}

/// Redacted body for "Reduce spoken detail" — no counts or lengths.
String postpartumStatusBodyRedacted(PostpartumCycleReturn r) =>
    switch (r.settling) {
      PostpartumSettling.awaitingFirstPeriod =>
        'No period logged since then. olf is waiting.',
      PostpartumSettling.firstCycleLogged =>
        'A first period has been logged. Not enough yet to show a pattern.',
      PostpartumSettling.settling =>
        'Your cycles since then look like they are settling.',
      PostpartumSettling.stillVariable =>
        'Your cycles since then are still varying.',
    };

/// How the p3 predictor is framed while the cycle is still returning.
const String postpartumPredictorNote =
    'Period predictions stay based on the periods you log. They are still '
    'settling and will sharpen as you log more full cycles.';

/// The not-a-medical-device line every mode screen carries (§6).
const String postpartumDisclaimer = SupportResources.notMedicalDeviceLine;
