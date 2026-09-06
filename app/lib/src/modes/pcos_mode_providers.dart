import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../symptom/symptom_providers.dart';

/// The descriptive symptom-vs-cycle-phase summary shown in PCOS mode (p7.4).
///
/// Pure `core` derivation ([cyclePhaseCorrelations]) over the symptom log and
/// the derived cycle history; `DateTime.now()` is read here at the edge, like
/// `prediction_providers` / `postpartumCycleReturnProvider`. Symptom names come
/// from the full catalogue (archived types included) so a later-removed symptom
/// is still named. Empty until both streams have loaded.
final pcosCorrelationsProvider = Provider<List<PhaseCorrelation>>((ref) {
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
