import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';

/// Neutral, non-clinical label for a pregnancy-end kind.
String pregnancyEndKindLabel(PregnancyEndKind kind) => switch (kind) {
  PregnancyEndKind.loss => 'Pregnancy loss',
  PregnancyEndKind.birth => 'Birth',
};

/// The event's date as a short day string, e.g. "4 May 2026".
String pregnancyEventDate(PregnancyEvent event) => formatDay(event.date);

/// "Pregnancy loss on 4 May 2026"
String pregnancyEventSummary(PregnancyEvent event) =>
    '${pregnancyEndKindLabel(event.kind)} on ${formatDay(event.date)}';

/// One-line explanation for the home banner, given the recovery state and the
/// date of the most recent pregnancy end.
String pregnancyBanner(PregnancyRecoveryState state, DateTime? since) {
  final on = since == null ? '' : ' on ${formatDay(since)}';
  return switch (state) {
    PregnancyRecoveryState.postpartum =>
      'You recorded a birth$on. olf has paused period estimates until your '
          'cycles return — log a period start when it does.',
    PregnancyRecoveryState.awaitingCyclesAfterLoss =>
      'You recorded a pregnancy loss$on. Estimates will come back once you have '
          'logged a couple of cycles.',
    PregnancyRecoveryState.none => '',
  };
}
