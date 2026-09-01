import 'package:olf_core/olf_core.dart';

/// p1.7's fixed wording — the title every kind still uses, and the medication
/// body (kept verbatim so that path is byte-identical). p4.1's per-kind bodies
/// live in `reminder_copy.dart` (`notificationCopyFor`); all follow the same
/// rule this comment states.
///
/// Deliberately generic: it names no medication, dosage, birth-control method
/// or symptom, and never will — it has to be safe sitting on a lock screen.
/// The "reminder text contains no health details" criterion is asserted in
/// `reminder_controller_test.dart` and `notification_copy_test.dart`.
const String reminderNotificationTitle = 'olf';
const String reminderNotificationBody = 'Time for your daily check-in.';

/// Schedules and cancels the per-category local reminders.
///
/// This is the seam the "test around the notification scheduling wrapper"
/// exercises: the app talks to this interface, the production implementation
/// ([LocalNotificationReminderScheduler]) wraps `flutter_local_notifications`,
/// and tests pass a fake. Every method replaces any existing notification for
/// the same [ReminderKind] (one stable id per kind), so scheduling is
/// idempotent and daily↔one-shot swaps are clean.
abstract interface class ReminderScheduler {
  /// Ask the OS for notification permission if it has not been granted yet.
  /// Returns whether notifications are permitted afterwards.
  Future<bool> ensurePermission();

  /// (Re)schedule a **daily** notification at [schedule]'s local `hour:minute`,
  /// replacing any existing one for [schedule.kind]. Callers pass only enabled
  /// schedules; a disabled one is a no-op. Used for the fixed-time kinds
  /// ([ReminderKind.medication], [ReminderKind.bbtPrompt]).
  Future<void> scheduleDaily(ReminderSchedule schedule);

  /// (Re)schedule a **one-shot** notification for [kind] at the exact local
  /// instant [when], replacing any existing one for [kind]. Used for the
  /// forecast-anchored kinds — the sync layer re-arms them whenever the forecast
  /// moves (see `reminder_planning.dart`). A [when] in the past fires as soon as
  /// the OS allows.
  Future<void> scheduleAt(ReminderKind kind, DateTime when);

  /// Cancel the notification for [kind], if one is scheduled.
  Future<void> cancel(ReminderKind kind);
}
