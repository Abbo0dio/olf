import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

/// Records what the app asked the OS-notification layer to do, so tests can
/// assert on it without a platform channel.
class FakeReminderScheduler implements ReminderScheduler {
  final List<ReminderSchedule> scheduled = <ReminderSchedule>[];
  final List<ReminderKind> cancelled = <ReminderKind>[];
  int permissionRequests = 0;

  /// What [ensurePermission] returns.
  bool permissionResult = true;

  ReminderSchedule? get lastScheduled =>
      scheduled.isEmpty ? null : scheduled.last;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return permissionResult;
  }

  @override
  Future<void> scheduleDaily(ReminderSchedule schedule) async {
    scheduled.add(schedule);
  }

  @override
  Future<void> cancel(ReminderKind kind) async {
    cancelled.add(kind);
  }
}
