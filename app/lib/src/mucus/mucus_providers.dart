import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../providers.dart';

/// Per-day cervical-mucus CRUD over the opened database.
final cervicalMucusRepositoryProvider = Provider<CervicalMucusRepository>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftCervicalMucusRepository(db);
});

/// Every logged cervical-mucus observation, live.
final cervicalMucusEntriesProvider = StreamProvider<List<CervicalMucusEntry>>((
  ref,
) {
  return ref.watch(cervicalMucusRepositoryProvider).watchAll();
});

/// The fertile window **as observed from this cycle's mucus notes**, or `null`
/// when nothing fertile-quality is logged yet. Feeds an extra line on the
/// prediction card without touching the statistical `Predictor` seam.
final observedFertileWindowProvider = Provider<DateRange?>((ref) {
  final cycles = ref.watch(cyclesProvider);
  if (cycles.isEmpty) return null;
  final entries =
      ref.watch(cervicalMucusEntriesProvider).value ??
      const <CervicalMucusEntry>[];
  return observedFertileWindow(
    entries,
    cycleStart: cycles.first.periodStart,
    today: DateTime.now(),
  );
});
