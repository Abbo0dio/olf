import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import '../health/health_sample.dart';
import 'daily_flow_repository.dart';

/// [DailyFlowRepository] backed by the drift [AppDatabase].
class DriftDailyFlowRepository implements DailyFlowRepository {
  DriftDailyFlowRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps the `createdAt` / `updatedAt` stamps deterministic
  /// in tests and the repository offline.
  final DateTime Function() _now;

  @override
  Future<DailyFlow?> flowOn(DateTime date) {
    final day = dateOnly(date);
    return (_db.select(
      _db.dailyFlows,
    )..where((t) => t.date.equals(day))).getSingleOrNull();
  }

  @override
  Stream<List<DailyFlow>> watchAll() {
    return (_db.select(_db.dailyFlows)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<List<DailyFlow>> allFlows() {
    return (_db.select(_db.dailyFlows)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Future<void> setFlow(
    DateTime date, {
    required FlowIntensity intensity,
    ClotSize? clotSize,
    HealthDataSource source = HealthDataSource.manual,
    String? externalId,
  }) async {
    final day = dateOnly(date);
    final stamp = _now();
    final existing = await flowOn(day);

    if (existing == null) {
      await _db
          .into(_db.dailyFlows)
          .insert(
            DailyFlowsCompanion.insert(
              date: day,
              intensity: intensity,
              clotSize: Value(clotSize),
              source: Value(source.name),
              externalId: Value(externalId),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      await (_db.update(
        _db.dailyFlows,
      )..where((t) => t.date.equals(day))).write(
        DailyFlowsCompanion(
          intensity: Value(intensity),
          clotSize: Value(clotSize),
          source: Value(source.name),
          externalId: Value(externalId),
          updatedAt: Value(stamp),
        ),
      );
    }
  }

  @override
  Future<void> clearFlow(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(_db.dailyFlows)..where((t) => t.date.equals(day))).go();
  }
}
