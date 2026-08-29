import 'package:olf_core/olf_core.dart';

/// The fixed wording of the reminder notification.
///
/// Deliberately generic: it names no medication, dosage, birth-control method
/// or symptom, and never will — it has to be safe sitting on a lock screen.
/// p1.7's acceptance criterion "reminder text contains no health details" is
/// enforced here and asserted in `reminder_controller_test.dart`. Phase 4's
/// richer notification system keeps the same rule.
const String reminderNotificationTitle = 'olf';
const String reminderNotificationBody = 'Time for your daily check-in.';

/// Schedules and cancels the one recurring local reminder p1.7 ships.
///
/// This is the seam the "test around the notification scheduling wrapper"
/// exercises: the app talks to this interface, the production implementation
/// ([LocalNotificationReminderScheduler]) wraps `flutter_local_notifications`,
/// and tests pass a fake.
abstract interface class ReminderScheduler {
  /// Ask the OS for notification permission if it has not been granted yet.
  /// Returns whether notifications are permitted afterwards.
  Future<bool> ensurePermission();

  /// (Re)schedule a daily notification at [schedule]'s local `hour:minute`,
  /// replacing any existing one for [schedule.kind]. Callers pass only enabled
  /// schedules; a disabled one is a no-op.
  Future<void> scheduleDaily(ReminderSchedule schedule);

  /// Cancel the daily notification for [kind], if one is scheduled.
  Future<void> cancel(ReminderKind kind);
}
