import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';

/// The production prediction engine.
///
/// p1.4 shipped `RobustPredictor` (v1) here; **p3.6 swaps in
/// [AdaptivePredictor] (v2)** — the only production wiring change in that slice.
/// Every call site (`predictionProvider`, the p3.3 correction loop, the p3.5
/// accuracy screen) reads this provider, so they all move to v2 with no edit.
/// `RobustPredictor` stays in the tree as the labelled v1 reference baseline for
/// the backtest harness — see [AdaptivePredictor] and `v1_baseline_test`.
final predictorProvider = Provider<Predictor>(
  (ref) => const AdaptivePredictor(),
);

/// The current forecast, or `null` when history is too thin. Recomputes off
/// [cyclesProvider], so any period add / edit / delete updates it on the same
/// screen with no stored state.
final predictionProvider = Provider<CyclePrediction?>((ref) {
  final cycles = ref.watch(cyclesProvider);
  return ref
      .watch(predictorProvider)
      .predict(cycles: cycles, today: DateTime.now());
});
