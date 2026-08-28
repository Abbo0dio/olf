import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_providers.dart';

/// The derived cycle history, newest first. Recomputes whenever
/// [periodsProvider] re-emits — so any period add / edit / delete flows through
/// with no stored state to invalidate. Empty until the periods stream loads.
final cyclesProvider = Provider<List<Cycle>>((ref) {
  final periods = ref.watch(periodsProvider).value ?? const <Period>[];
  return deriveCycles(periods);
});

/// Summary statistics over [cyclesProvider]. Also a plain `Provider` — pure
/// derivation, no I/O.
final cycleStatsProvider = Provider<CycleStats>((ref) {
  return CycleStats.from(ref.watch(cyclesProvider));
});
