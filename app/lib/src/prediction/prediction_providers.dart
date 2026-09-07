import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../cycle/cycle_providers.dart';

/// The production prediction engine.
///
/// p1.4 shipped `RobustPredictor` (v1) here; **p3.6 swaps in
/// [AdaptivePredictor] (v2)** — the only production wiring change in that slice.
/// The p3.3 correction loop and the p3.5 accuracy screen read this provider
/// directly, so they stay on the pure length-series model. `RobustPredictor`
/// stays in the tree as the labelled v1 reference baseline for the backtest
/// harness — see [AdaptivePredictor] and `v1_baseline_test`.
final predictorProvider = Provider<Predictor>(
  (ref) => const AdaptivePredictor(),
);

/// The current forecast, or `null` when history is too thin. Recomputes off
/// [cyclesProvider] and [bbtEntriesProvider], so any period or temperature
/// add / edit / delete updates it on the same screen with no stored state.
///
/// p8.5: wrapped in a [PassiveInformedPredictor] so a confirmed passive
/// temperature shift re-anchors **only** this cycle's fertile window on the
/// observed ovulation. Every next-period field is left exactly as
/// [predictorProvider] produced it, and with no passive temperature data the
/// result is byte-identical to the bare forecast.
final predictionProvider = Provider<CyclePrediction?>((ref) {
  final cycles = ref.watch(cyclesProvider);
  final temps = ref.watch(bbtEntriesProvider).valueOrNull ?? const <BbtEntry>[];
  return PassiveInformedPredictor(
    inner: ref.watch(predictorProvider),
    temperatures: temps,
  ).predict(cycles: cycles, today: DateTime.now());
});
