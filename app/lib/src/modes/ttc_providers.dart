import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../cycle/cycle_providers.dart';
import '../mucus/mucus_providers.dart';
import '../prediction/prediction_providers.dart';

/// How many days the TTC outlook covers: today plus the next seven.
const int ttcOutlookDays = 8;

/// The daily fertility outlook for TTC mode (p7.3): today and the next
/// [ttcOutlookDays] − 1 days, each a [DailyFertilityScore].
///
/// Empty when there is not enough history for an honest estimate — the screen
/// shows a "keep logging" state. Pure `core` does the scoring; `DateTime.now()`
/// is read here at the edge, matching `predictionProvider` /
/// `postpartumCycleReturnProvider`.
final ttcFertilityOutlookProvider = Provider<List<DailyFertilityScore>>((ref) {
  final cycles = ref.watch(cyclesProvider);
  final prediction = ref.watch(predictionProvider);
  final bbt = ref.watch(bbtEntriesProvider).value ?? const <BbtEntry>[];
  final mucus =
      ref.watch(cervicalMucusEntriesProvider).value ??
      const <CervicalMucusEntry>[];

  return dailyFertilityScores(
    cycles: cycles,
    bbt: bbt,
    mucus: mucus,
    prediction: prediction,
    today: DateTime.now(),
    days: ttcOutlookDays,
  );
});
