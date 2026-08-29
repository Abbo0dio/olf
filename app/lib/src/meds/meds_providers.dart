import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';

/// Medication-list CRUD over the opened database. Only valid inside the `data`
/// branch of the database gate (see [appDatabaseProvider]).
final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftMedicationRepository(db);
});

/// The active (non-archived) medication list, live and name-ordered. Not
/// `autoDispose` — same reasoning as the other repository streams.
final medicationsProvider = StreamProvider<List<Medication>>((ref) {
  return ref.watch(medicationRepositoryProvider).watchActive();
});

/// Birth-control history CRUD over the opened database.
final birthControlRepositoryProvider = Provider<BirthControlRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftBirthControlRepository(db);
});

/// The current birth-control entry (`null` if none is set), live.
final currentBirthControlProvider = StreamProvider<BirthControlEntry?>((ref) {
  return ref.watch(birthControlRepositoryProvider).watchCurrent();
});
