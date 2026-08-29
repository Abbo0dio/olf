import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';

/// The prediction engine. A plain `const RobustPredictor` for p1.4; Phase 3
/// swaps in an adaptive model here without any call site changing.
final predictorProvider = Provider<Predictor>((ref) => const RobustPredictor());

/// The current forecast, or `null` when history is too thin. Recomputes off
/// [cyclesProvider], so any period add / edit / delete updates it on the same
/// screen with no stored state.
final predictionProvider = Provider<CyclePrediction?>((ref) {
  final cycles = ref.watch(cyclesProvider);
  return ref
      .watch(predictorProvider)
      .predict(cycles: cycles, today: DateTime.now());
});
