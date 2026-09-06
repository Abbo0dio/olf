import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../providers.dart';

/// Pain / flare log CRUD over the opened database (p7.5). Only valid inside the
/// `data` branch of the database gate (see [appDatabaseProvider]).
final painRepositoryProvider = Provider<PainRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftPainRepository(db);
});

/// Every logged pain / flare day, newest first, live. Not `autoDispose` — the
/// screen and the log sheet both listen (same reasoning as `symptomEntries`).
final painEntriesProvider = StreamProvider<List<PainEntry>>((ref) {
  return ref.watch(painRepositoryProvider).watchAll();
});

/// Descriptive `Pain` / `Flare` vs cycle-phase summaries (p7.5), via the p7.4
/// [cyclePhaseCorrelations] core over the pain log and the derived cycles.
/// `DateTime.now()` is read here at the edge, like `prediction_providers`.
/// Empty until the pain stream has loaded.
final endometriosisCorrelationsProvider = Provider<List<PhaseCorrelation>>((
  ref,
) {
  final entries = ref.watch(painEntriesProvider).valueOrNull;
  if (entries == null || entries.isEmpty) return const <PhaseCorrelation>[];

  return cyclePhaseCorrelations(
    events: painFlareEvents(entries),
    cycles: ref.watch(cyclesProvider),
    today: DateTime.now(),
  );
});
