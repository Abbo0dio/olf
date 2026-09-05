import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../health/health_sample.dart';
import 'bbt_repository.dart';
import 'temperature.dart';

/// [BbtRepository] backed by the drift [AppDatabase].
class DriftBbtRepository implements BbtRepository {
  DriftBbtRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<BbtEntry?> tempOn(DateTime date) {
    final day = dateOnly(date);
    return (_db.select(
      _db.bbtEntries,
    )..where((t) => t.date.equals(day))).getSingleOrNull();
  }

  @override
  Stream<List<BbtEntry>> watchAll() {
    return (_db.select(_db.bbtEntries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<List<BbtEntry>> allEntries() {
    return (_db.select(_db.bbtEntries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Future<void> setTemp(
    DateTime date,
    double celsius, {
    HealthDataSource source = HealthDataSource.manual,
    String? externalId,
  }) async {
    final error = validateCelsius(celsius);
    if (error != null) throw BbtException(error);

    final day = dateOnly(date);
    final stamp = _now();
    final existing = await tempOn(day);

    if (existing == null) {
      await _db
          .into(_db.bbtEntries)
          .insert(
            BbtEntriesCompanion.insert(
              date: day,
              tempCelsius: celsius,
              source: Value(source.name),
              externalId: Value(externalId),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      await (_db.update(
        _db.bbtEntries,
      )..where((t) => t.date.equals(day))).write(
        BbtEntriesCompanion(
          tempCelsius: Value(celsius),
          source: Value(source.name),
          externalId: Value(externalId),
          updatedAt: Value(stamp),
        ),
      );
    }
  }

  @override
  Future<void> clearTemp(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(_db.bbtEntries)..where((t) => t.date.equals(day))).go();
  }
}
