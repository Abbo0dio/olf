import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'medication.dart';
import 'medication_repository.dart';

/// [MedicationRepository] backed by the drift [AppDatabase].
class DriftMedicationRepository implements MedicationRepository {
  DriftMedicationRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps the `createdAt` / `updatedAt` / `archivedAt`
  /// stamps deterministic in tests and the repository offline.
  final DateTime Function() _now;

  SimpleSelectStatement<$MedicationsTable, Medication> _activeSelect() =>
      _db.select(_db.medications)
        ..where((t) => t.archivedAt.isNull())
        ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]);

  @override
  Stream<List<Medication>> watchActive() => _activeSelect().watch();

  @override
  Future<List<Medication>> activeMedications() => _activeSelect().get();

  @override
  Future<Medication> add(String name, {String? dosage, String? notes}) async {
    final error = validateMedicationName(name);
    if (error != null) throw MedicationException(error);

    final stamp = _now();
    final id = await _db
        .into(_db.medications)
        .insert(
          MedicationsCompanion.insert(
            name: name.trim(),
            dosage: Value(_clean(dosage)),
            notes: Value(_clean(notes)),
            createdAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
    return (_db.select(
      _db.medications,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  @override
  Future<void> edit(
    int id, {
    required String name,
    String? dosage,
    String? notes,
  }) async {
    final error = validateMedicationName(name);
    if (error != null) throw MedicationException(error);

    await (_db.update(_db.medications)..where((t) => t.id.equals(id))).write(
      MedicationsCompanion(
        name: Value(name.trim()),
        dosage: Value(_clean(dosage)),
        notes: Value(_clean(notes)),
        updatedAt: Value(_now()),
      ),
    );
  }

  @override
  Future<void> archive(int id) async {
    final stamp = _now();
    await (_db.update(_db.medications)..where((t) => t.id.equals(id))).write(
      MedicationsCompanion(archivedAt: Value(stamp), updatedAt: Value(stamp)),
    );
  }

  @override
  Future<void> unarchive(int id) async {
    await (_db.update(_db.medications)..where((t) => t.id.equals(id))).write(
      MedicationsCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// Trim a free-text field; treat blank as "not set".
  static String? _clean(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
