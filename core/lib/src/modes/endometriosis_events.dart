import '../db/app_database.dart';
import 'cycle_phase_correlation.dart';

/// The two [PhaseEvent] categories the endometriosis view feeds into
/// [cyclePhaseCorrelations] (p7.5).
///
/// Kept as constants so the screen copy and the tests refer to the same
/// strings the correlation groups by.
const String painEventCategory = 'Pain';
const String flareEventCategory = 'Flare';

/// Map the pain / flare log to the generic [PhaseEvent] stream the p7.4
/// correlation core consumes.
///
/// Every logged day is a `Pain` event; a day the user marked a flare is *also*
/// a `Flare` event, so the two categories answer "when does pain land in my
/// cycle" and "when do flares cluster" independently. Pure and order-preserving
/// — the correlation core owns dedup / windowing.
List<PhaseEvent> painFlareEvents(Iterable<PainEntry> entries) {
  final events = <PhaseEvent>[];
  for (final e in entries) {
    events.add(PhaseEvent(day: e.date, category: painEventCategory));
    if (e.isFlare) {
      events.add(PhaseEvent(day: e.date, category: flareEventCategory));
    }
  }
  return events;
}
