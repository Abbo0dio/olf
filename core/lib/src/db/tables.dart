import 'package:drift/drift.dart';

/// The kinds of event that can sit on the cycle timeline.
///
/// v1 has exactly one — the day a period started. Phase 1 extends this
/// (period end, loss, birth, …); each addition is a schema migration.
enum CycleEventType { periodStart }

/// One dated event on the user's cycle timeline.
///
/// `date` is a **calendar date** (local, time-of-day zeroed) — "Day N" must be
/// stable regardless of what time the row was written. `createdAt` is kept as an
/// audit trail so a later correction can be told apart from the original entry.
class CycleEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get type => textEnum<CycleEventType>()();

  DateTimeColumn get date => dateTime()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
