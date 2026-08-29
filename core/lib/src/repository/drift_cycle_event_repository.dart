import 'package:drift/drift.dart';

import '../cycle/pregnancy_event.dart';
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
  Future<int> logPregnancyEnd(PregnancyEndKind kind, DateTime date) {
    return _db
        .into(_db.cycleEvents)
        .insert(
          CycleEventsCompanion.insert(
            type: kind.eventType,
            date: dateOnly(date),
          ),
        );
  }

  @override
  Stream<List<PregnancyEvent>> watchPregnancyEvents() =>
      _pregnancyEventsQuery().watch().map(_toPregnancyEvents);

  @override
  Future<List<PregnancyEvent>> pregnancyEvents() =>
      _pregnancyEventsQuery().get().then(_toPregnancyEvents);

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

  SimpleSelectStatement<$CycleEventsTable, CycleEvent> _pregnancyEventsQuery() {
    return _db.select(_db.cycleEvents)
      ..where(
        (t) =>
            t.type.equalsValue(CycleEventType.pregnancyLoss) |
            t.type.equalsValue(CycleEventType.birth),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.id),
      ]);
  }

  List<PregnancyEvent> _toPregnancyEvents(List<CycleEvent> rows) => [
    for (final row in rows)
      if (PregnancyEvent.fromRow(row) case final event?) event,
  ];
}
