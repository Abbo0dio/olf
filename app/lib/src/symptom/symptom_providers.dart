import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';

/// Symptom catalogue + per-day entry CRUD over the opened database. Only valid
/// inside the `data` branch of the database gate (see [appDatabaseProvider]).
final symptomRepositoryProvider = Provider<SymptomRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftSymptomRepository(db);
});

/// The active symptom catalogue, live and ordered. Not `autoDispose` — the
/// calendar and the day sheet both listen, and disposing a drift stream
/// mid-frame leaves a close timer pending (trips widget tests). Same reasoning
/// as `periodsProvider` / `dailyFlowsProvider`.
final symptomTypesProvider = StreamProvider<List<SymptomType>>((ref) {
  return ref.watch(symptomRepositoryProvider).watchTypes();
});

/// Every logged symptom entry, newest day first, live.
final symptomEntriesProvider = StreamProvider<List<DailySymptomEntry>>((ref) {
  return ref.watch(symptomRepositoryProvider).watchAllEntries();
});

/// The whole symptom catalogue, archived entries included — so a historical
/// entry whose symptom was later removed can still be named (the p6.5 doctor
/// report). One-shot, not live: callers read it at the moment they build a
/// report.
final allSymptomTypesProvider = FutureProvider<List<SymptomType>>((ref) {
  return ref.watch(symptomRepositoryProvider).allTypes();
});
