import 'package:olf_core/olf_core.dart';

import 'reminder_scheduler.dart';

/// Orchestrates the single daily reminder: it keeps the stored
/// [ReminderSchedule] and the OS-level notification in step.
///
/// The UI calls [setEnabled] / [setTime]; it never talks to the
/// [ReminderScheduler] directly. Writing the row is what drives the
/// `medicationReminderProvider` stream the screen listens to.
class ReminderController {
  ReminderController(this._repository, this._scheduler);

  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;

  /// Used the first time the user turns the reminder on without having picked a
  /// time — a neutral mid-morning default.
  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  static const ReminderSchedule _fallback = ReminderSchedule(
    kind: ReminderKind.medication,
    hour: defaultHour,
    minute: defaultMinute,
    enabled: false,
  );

  Future<ReminderSchedule> _currentOrFallback() async =>
      await _repository.get(ReminderKind.medication) ?? _fallback;

  /// Turn the daily reminder on or off. Turning it on first asks for
  /// notification permission, then schedules; turning it off cancels.
  Future<void> setEnabled({required bool enabled}) async {
    final next = (await _currentOrFallback()).copyWith(enabled: enabled);

    if (enabled) {
      await _scheduler.ensurePermission();
      await _repository.save(next);
      await _scheduler.scheduleDaily(next);
    } else {
      await _repository.save(next);
      await _scheduler.cancel(ReminderKind.medication);
    }
  }

  /// Change the time of day the reminder fires. Reschedules only when the
  /// reminder is currently enabled.
  Future<void> setTime({required int hour, required int minute}) async {
    final next = (await _currentOrFallback()).copyWith(
      hour: hour,
      minute: minute,
    );
    await _repository.save(next);
    if (next.enabled) {
      await _scheduler.scheduleDaily(next);
    }
  }
}
