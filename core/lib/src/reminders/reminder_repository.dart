import '../db/tables.dart';
import 'reminder_schedule.dart';

/// Reads and writes the stored recurring reminders ([Reminder]).
///
/// p1.7 keeps exactly one row (`kind = ReminderKind.medication`). The table and
/// this seam are shaped so Phase 4 can generalise without a rewrite.
abstract interface class ReminderRepository {
  /// The stored schedule for [kind], or `null` if the user has never set one.
  Future<ReminderSchedule?> get(ReminderKind kind);

  /// The stored schedule for [kind] as a stream that re-emits on every write
  /// (starting with the current value, or `null`).
  Stream<ReminderSchedule?> watch(ReminderKind kind);

  /// Insert or update the row for [schedule.kind]. Throws [ReminderException]
  /// if the time is out of range (`validateReminderTime`).
  Future<void> save(ReminderSchedule schedule);
}
