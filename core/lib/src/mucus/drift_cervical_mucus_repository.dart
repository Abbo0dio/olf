import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import 'cervical_mucus_repository.dart';

/// [CervicalMucusRepository] backed by the drift [AppDatabase].
class DriftCervicalMucusRepository implements CervicalMucusRepository {
  DriftCervicalMucusRepository(
    this._db, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<CervicalMucusEntry?> mucusOn(DateTime date) {
    final day = dateOnly(date);
    return (_db.select(
      _db.cervicalMucusEntries,
    )..where((t) => t.date.equals(day))).getSingleOrNull();
  }

  @override
  Stream<List<CervicalMucusEntry>> watchAll() {
    return (_db.select(_db.cervicalMucusEntries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<void> setMucus(DateTime date, CervicalMucusType type) async {
    final day = dateOnly(date);
    final stamp = _now();
    final existing = await mucusOn(day);

    if (existing == null) {
      await _db
          .into(_db.cervicalMucusEntries)
          .insert(
            CervicalMucusEntriesCompanion.insert(
              date: day,
              type: type,
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      await (_db.update(
        _db.cervicalMucusEntries,
      )..where((t) => t.date.equals(day))).write(
        CervicalMucusEntriesCompanion(
          type: Value(type),
          updatedAt: Value(stamp),
        ),
      );
    }
  }

  @override
  Future<void> clearMucus(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(
      _db.cervicalMucusEntries,
    )..where((t) => t.date.equals(day))).go();
  }
}
