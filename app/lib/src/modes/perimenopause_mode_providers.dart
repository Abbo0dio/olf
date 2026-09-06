import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../period/period_providers.dart';
import '../symptom/symptom_providers.dart';
import 'perimenopause_format.dart';

/// The descriptive transition read shown in perimenopause mode (p7.7). Pure
/// `core` derivation ([derivePerimenopauseTransition]) over the logged period
/// history; `DateTime.now()` is read here at the edge, like
/// `prediction_providers` / `pcosCorrelationsProvider`. `null` until the period
/// stream has loaded or when nothing is logged.
final perimenopauseTransitionProvider = Provider<PerimenopauseTransitionRead?>((
  ref,
) {
  final periods = ref.watch(periodsProvider).valueOrNull ?? const <Period>[];
  if (periods.isEmpty) return null;
  return derivePerimenopauseTransition(periods: periods, today: DateTime.now());
});

/// The perimenopause symptom timeline: [cyclePhaseCorrelations] over the logged
/// symptoms, filtered to the perimenopause-relevant set — the bundled
/// [kPerimenopauseSymptomNames] plus the user's own (non-built-in) symptoms.
/// No new storage; reuses the p1.5 symptom log and the p7.4 correlation core.
/// Empty until both streams have loaded.
final perimenopauseCorrelationsProvider = Provider<List<PhaseCorrelation>>((
  ref,
) {
  final entries =
      ref.watch(symptomEntriesProvider).valueOrNull ??
      const <DailySymptomEntry>[];
  final allTypes =
      ref.watch(allSymptomTypesProvider).valueOrNull ?? const <SymptomType>[];
  if (entries.isEmpty || allTypes.isEmpty) return const <PhaseCorrelation>[];

  const builtInRelevant = <String>{...kPerimenopauseSymptomNames};
  final relevantNames = <String>{};
  final nameById = <int, String>{};
  for (final t in allTypes) {
    nameById[t.id] = t.name;
    if (!t.isBuiltIn || builtInRelevant.contains(t.name)) {
      relevantNames.add(t.name);
    }
  }

  final events = <PhaseEvent>[
    for (final e in entries)
      if (nameById[e.symptomTypeId] case final name?)
        if (relevantNames.contains(name))
          PhaseEvent(day: e.date, category: name),
  ];
  if (events.isEmpty) return const <PhaseCorrelation>[];

  return cyclePhaseCorrelations(
    events: events,
    cycles: ref.watch(cyclesProvider),
    today: DateTime.now(),
  );
});
