import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_providers.dart';
import '../pregnancy/pregnancy_providers.dart';

/// The derived cycle history, newest first. Recomputes whenever
/// [periodsProvider] or [pregnancyEventsProvider] re-emits — so any period or
/// loss / birth add / edit / delete flows through with no stored state to
/// invalidate. Empty until the periods stream loads.
///
/// A recorded pregnancy loss / birth (p1.11) marks the interval it falls in as
/// a [Cycle.isPregnancyGap], which `CycleStats` and `RobustPredictor` then
/// treat as a reset of the cycle baseline.
final cyclesProvider = Provider<List<Cycle>>((ref) {
  final periods = ref.watch(periodsProvider).value ?? const <Period>[];
  final pregnancyEvents =
      ref.watch(pregnancyEventsProvider).value ?? const <PregnancyEvent>[];
  return deriveCycles(periods, pregnancyEvents: pregnancyEvents);
});

/// Summary statistics over [cyclesProvider]. Also a plain `Provider` — pure
/// derivation, no I/O.
final cycleStatsProvider = Provider<CycleStats>((ref) {
  return CycleStats.from(ref.watch(cyclesProvider));
});
