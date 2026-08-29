import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import 'symptom_repository.dart';
import 'symptom_validation.dart';

/// [SymptomRepository] backed by the drift [AppDatabase].
class DriftSymptomRepository implements SymptomRepository {
  DriftSymptomRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps the `createdAt` / `updatedAt` / `archivedAt`
  /// stamps deterministic in tests and the repository offline.
  final DateTime Function() _now;

  @override
  Stream<List<SymptomType>> watchTypes() => _activeSelect().watch();

  @override
  Future<List<SymptomType>> activeTypes() => _activeSelect().get();

  SimpleSelectStatement<$SymptomTypesTable, SymptomType> _activeSelect() =>
      _db.select(_db.symptomTypes)
        ..where((t) => t.archivedAt.isNull())
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);

  @override
  Future<SymptomType> addType(String name) async {
    final active = await activeTypes();
    final error = validateSymptomName(
      name,
      existingActiveNames: active.map((t) => t.name),
    );
    if (error != null) throw SymptomTypeException(error);

    final stamp = _now();
    final nextOrder = active.isEmpty
        ? 0
        : active.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final id = await _db
        .into(_db.symptomTypes)
        .insert(
          SymptomTypesCompanion.insert(
            name: name.trim(),
            sortOrder: nextOrder,
            createdAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
    return (_db.select(
      _db.symptomTypes,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  @override
  Future<void> renameType(int id, String name) async {
    final active = await activeTypes();
    SymptomType? current;
    for (final t in active) {
      if (t.id == id) {
        current = t;
        break;
      }
    }
    final error = validateSymptomName(
      name,
      existingActiveNames: active.map((t) => t.name),
      editingCurrentName: current?.name,
    );
    if (error != null) throw SymptomTypeException(error);

    await (_db.update(_db.symptomTypes)..where((t) => t.id.equals(id))).write(
      SymptomTypesCompanion(name: Value(name.trim()), updatedAt: Value(_now())),
    );
  }

  @override
  Future<void> reorderTypes(List<int> orderedIds) async {
    final stamp = _now();
    await _db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          _db.symptomTypes,
          SymptomTypesCompanion(sortOrder: Value(i), updatedAt: Value(stamp)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  @override
  Future<void> archiveType(int id) async {
    final stamp = _now();
    await (_db.update(_db.symptomTypes)..where((t) => t.id.equals(id))).write(
      SymptomTypesCompanion(archivedAt: Value(stamp), updatedAt: Value(stamp)),
    );
  }

  @override
  Future<Set<int>> symptomsOn(DateTime date) async {
    final day = dateOnly(date);
    final rows = await (_db.select(
      _db.dailySymptomEntries,
    )..where((t) => t.date.equals(day))).get();
    return rows.map((r) => r.symptomTypeId).toSet();
  }

  @override
  Stream<List<DailySymptomEntry>> watchAllEntries() =>
      (_db.select(_db.dailySymptomEntries)..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
          .watch();

  @override
  Future<void> setSymptom(
    DateTime date,
    int typeId, {
    required bool present,
  }) async {
    final day = dateOnly(date);
    if (present) {
      await _db
          .into(_db.dailySymptomEntries)
          .insert(
            DailySymptomEntriesCompanion.insert(
              date: day,
              symptomTypeId: typeId,
              createdAt: Value(_now()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.delete(_db.dailySymptomEntries)
            ..where((t) => t.date.equals(day) & t.symptomTypeId.equals(typeId)))
          .go();
    }
  }

  @override
  Future<void> clearDay(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(
      _db.dailySymptomEntries,
    )..where((t) => t.date.equals(day))).go();
  }
}
