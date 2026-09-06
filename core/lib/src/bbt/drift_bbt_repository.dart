import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart' show BbtMeasurementKind;
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
    BbtMeasurementKind measurementKind = BbtMeasurementKind.basal,
    String? sourceDevice,
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
              measurementKind: Value(measurementKind),
              sourceDevice: Value(sourceDevice),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      // `externalId` is sticky: an in-app edit (which passes no id) keeps the
      // row linked to its platform record so a p6.4 write-back updates that
      // record in place instead of inserting a duplicate. The `source` still
      // moves to whatever the caller passed — `manual` by default, i.e. an
      // edit flips a previously-imported row back to the user's own (p6.1).
      //
      // `measurementKind` is NOT sticky (p8.1a): it moves to whatever the
      // caller passed — `basal` by default — so correcting a passive Apple
      // Watch wrist reading in-app turns it into a typed basal temperature.
      //
      // `sourceDevice` is NOT sticky either (p8.2): an in-app edit passes no
      // tag and the row's `source_device` is cleared to `null`.
      await (_db.update(
        _db.bbtEntries,
      )..where((t) => t.date.equals(day))).write(
        BbtEntriesCompanion(
          tempCelsius: Value(celsius),
          source: Value(source.name),
          externalId: Value(externalId ?? existing.externalId),
          measurementKind: Value(measurementKind),
          sourceDevice: Value(sourceDevice),
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
