import 'package:drift/drift.dart';

/// The kinds of point-in-time event that can sit on the cycle timeline.
///
/// v1 had exactly one — the day a period started. As of schema v2, period
/// tracking moved to its own interval table ([Periods]); this log stays for
/// the point-in-time markers p1.11 adds (loss, birth, postpartum).
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

/// One logged menstrual period: a start date and an **optional** end date.
///
/// Both are **calendar dates** (local, time-of-day zeroed on write). `endDate`
/// is `null` while a period is ongoing or the user simply hasn't recorded when
/// it stopped. `updatedAt` is bumped on every edit so a later correction can be
/// told apart from the original entry (and so the "fixing a past period does not
/// cascade forward" guarantee is auditable).
///
/// Introduced in schema v2 (p1.1). Overlap / impossible-range rules are enforced
/// in `PeriodRepository`, not by the database.
@DataClassName('Period')
class Periods extends Table {
  IntColumn get id => integer().autoIncrement()();

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Menstrual-flow intensity for a single day, lightest to heaviest.
enum FlowIntensity { spotting, light, medium, heavy }

/// Optional clot-size note for a single day.
enum ClotSize { small, medium, large }

/// What the user recorded about a single calendar day's bleeding.
///
/// Keyed by `date` (one row per day), and deliberately **not** linked to a
/// [Periods] row: editing or deleting a period must never disturb what was
/// logged for a day. Introduced in schema v3 (p1.2).
@DataClassName('DailyFlow')
class DailyFlows extends Table {
  /// Calendar date, time-of-day zeroed on write. Primary key.
  DateTimeColumn get date => dateTime()();

  TextColumn get intensity => textEnum<FlowIntensity>()();

  TextColumn get clotSize => textEnum<ClotSize>().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {date};
}
