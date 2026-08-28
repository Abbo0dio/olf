import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import 'cycle_event_repository.dart';

/// [CycleEventRepository] backed by the drift [AppDatabase].
class DriftCycleEventRepository implements CycleEventRepository {
  DriftCycleEventRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> logPeriodStart(DateTime date) {
    return _db
        .into(_db.cycleEvents)
        .insert(
          CycleEventsCompanion.insert(
            type: CycleEventType.periodStart,
            date: dateOnly(date),
          ),
        );
  }

  @override
  Future<CycleEvent?> mostRecentPeriodStart() =>
      _mostRecentPeriodStartQuery().getSingleOrNull();

  @override
  Stream<CycleEvent?> watchMostRecentPeriodStart() =>
      _mostRecentPeriodStartQuery().watchSingleOrNull();

  @override
  Future<void> deleteEvent(int id) async {
    await (_db.delete(_db.cycleEvents)..where((t) => t.id.equals(id))).go();
  }

  SimpleSelectStatement<$CycleEventsTable, CycleEvent>
  _mostRecentPeriodStartQuery() {
    return _db.select(_db.cycleEvents)
      ..where((t) => t.type.equalsValue(CycleEventType.periodStart))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
  }
}
