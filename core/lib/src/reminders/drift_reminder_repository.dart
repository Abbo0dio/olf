import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/tables.dart';
import 'reminder_repository.dart';
import 'reminder_schedule.dart';

/// [ReminderRepository] backed by the drift [AppDatabase].
class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  SimpleSelectStatement<$RemindersTable, Reminder> _select(ReminderKind kind) =>
      _db.select(_db.reminders)..where((t) => t.kind.equalsValue(kind));

  @override
  Future<ReminderSchedule?> get(ReminderKind kind) async {
    final row = await _select(kind).getSingleOrNull();
    return row == null ? null : _toSchedule(row);
  }

  @override
  Stream<ReminderSchedule?> watch(ReminderKind kind) => _select(
    kind,
  ).watchSingleOrNull().map((row) => row == null ? null : _toSchedule(row));

  @override
  Future<void> save(ReminderSchedule schedule) async {
    final error = validateReminderTime(schedule.hour, schedule.minute);
    if (error != null) throw ReminderException(error);

    final stamp = _now();
    final existing = await _select(schedule.kind).getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.reminders)
          .insert(
            RemindersCompanion.insert(
              kind: schedule.kind,
              hour: schedule.hour,
              minute: schedule.minute,
              enabled: Value(schedule.enabled),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      await (_db.update(
        _db.reminders,
      )..where((t) => t.id.equals(existing.id))).write(
        RemindersCompanion(
          hour: Value(schedule.hour),
          minute: Value(schedule.minute),
          enabled: Value(schedule.enabled),
          updatedAt: Value(stamp),
        ),
      );
    }
  }

  static ReminderSchedule _toSchedule(Reminder row) => ReminderSchedule(
    kind: row.kind,
    hour: row.hour,
    minute: row.minute,
    enabled: row.enabled,
  );
}
