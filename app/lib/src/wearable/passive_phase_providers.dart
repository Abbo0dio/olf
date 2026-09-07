import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../cycle/cycle_providers.dart';
import '../prediction/prediction_providers.dart';

/// The passive cycle-phase inference for the current cycle (p8.5), or `null`
/// when the temperature signal is too thin / shows no confirmed shift.
///
/// Pure derivation over [bbtEntriesProvider] + [cyclesProvider] + the bare
/// forecast — recomputes whenever any of those change, so a logged period or a
/// new temperature reading flows straight through with no stored state. The
/// bare `predictorProvider` forecast (not the passive-informed one) is passed as
/// the inference's cross-check argument to avoid a provider cycle.
final passivePhaseEstimateProvider = Provider<PassivePhaseEstimate?>((ref) {
  final cycles = ref.watch(cyclesProvider);
  final temps = ref.watch(bbtEntriesProvider).valueOrNull ?? const <BbtEntry>[];
  final today = DateTime.now();
  final base = ref
      .watch(predictorProvider)
      .predict(cycles: cycles, today: today);
  return inferPassivePhase(
    temperatures: temps,
    cycles: cycles,
    prediction: base,
    today: today,
  );
});
