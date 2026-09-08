import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../symptom/symptom_providers.dart';

/// The descriptive symptom-vs-cycle-phase summary (p7.4 `cyclePhaseCorrelations`
/// core) over the whole symptom log and the derived cycle history.
///
/// Landed as `pcosCorrelationsProvider` in p7.4; nothing about it was ever
/// PCOS-specific — it covers every logged symptom — so r3b lifts it here to
/// back the Patterns tab's correlations section as well as the PCOS screen.
///
/// `DateTime.now()` is read here at the edge, like `prediction_providers` /
/// `postpartumCycleReturnProvider`. Symptom names come from the full catalogue
/// (archived types included) so a later-removed symptom is still named. Empty
/// until both streams have loaded.
final symptomPhaseCorrelationsProvider = Provider<List<PhaseCorrelation>>((ref) {
  final entries =
      ref.watch(symptomEntriesProvider).valueOrNull ??
      const <DailySymptomEntry>[];
  final allTypes =
      ref.watch(allSymptomTypesProvider).valueOrNull ?? const <SymptomType>[];
  if (entries.isEmpty || allTypes.isEmpty) return const <PhaseCorrelation>[];

  final nameById = {for (final t in allTypes) t.id: t.name};
  final events = <PhaseEvent>[
    for (final e in entries)
      if (nameById[e.symptomTypeId] case final name?)
        PhaseEvent(day: e.date, category: name),
  ];

  return cyclePhaseCorrelations(
    events: events,
    cycles: ref.watch(cyclesProvider),
    today: DateTime.now(),
  );
});
