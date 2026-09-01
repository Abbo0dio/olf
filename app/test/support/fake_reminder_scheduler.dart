import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

/// Records what the app asked the OS-notification layer to do, so tests can
/// assert on it without a platform channel.
class FakeReminderScheduler implements ReminderScheduler {
  final List<ReminderSchedule> scheduled = <ReminderSchedule>[];
  final List<({ReminderKind kind, DateTime when})> oneShots =
      <({ReminderKind kind, DateTime when})>[];
  final List<ReminderKind> cancelled = <ReminderKind>[];
  int permissionRequests = 0;

  /// What [ensurePermission] returns.
  bool permissionResult = true;

  ReminderSchedule? get lastScheduled =>
      scheduled.isEmpty ? null : scheduled.last;

  /// The last one-shot instant armed for [kind] that was not since cancelled,
  /// or `null` — mirrors the real "one stable notification id per kind".
  DateTime? oneShotFor(ReminderKind kind) {
    DateTime? armed;
    for (final e in _timeline) {
      if (e.kind != kind) continue;
      armed = e.when; // a cancel records `when: null`
    }
    return armed;
  }

  final List<({ReminderKind kind, DateTime? when})> _timeline =
      <({ReminderKind kind, DateTime? when})>[];

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
  Future<void> scheduleAt(ReminderKind kind, DateTime when) async {
    oneShots.add((kind: kind, when: when));
    _timeline.add((kind: kind, when: when));
  }

  @override
  Future<void> cancel(ReminderKind kind) async {
    cancelled.add(kind);
    _timeline.add((kind: kind, when: null));
  }
}
