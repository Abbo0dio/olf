import 'package:olf_core/olf_core.dart';

import 'reminder_scheduler.dart';

/// Keeps a stored [ReminderSchedule] and its OS notification in step, for **any**
/// [ReminderKind] (p4.1 — p1.7 handled only `medication`).
///
/// The UI calls [setEnabled] / [setTime]; it never talks to the
/// [ReminderScheduler] directly. Writing the row is what drives the per-kind
/// stream the screens listen to.
///
/// Fixed-time kinds ([ReminderKind.medication], [ReminderKind.bbtPrompt]) are
/// scheduled as a daily notification. Forecast-anchored kinds are scheduled as a
/// one-shot at the instant `reminder_planning.dart` computes from the current
/// [CyclePrediction]; `reminderSyncProvider` re-arms them when the forecast
/// moves. If there is no usable forecast yet, enabling stores the preference and
/// arms nothing — the sync pass picks it up once a prediction exists.
class ReminderController {
  ReminderController(
    this._repository,
    this._scheduler, {
    required CyclePrediction? Function() prediction,
    Future<int?> Function() preferredHour = _noPreferredHour,
    DateTime Function() now = DateTime.now,
  }) : _prediction = prediction,
       _preferredHour = preferredHour,
       _now = now;

  static Future<int?> _noPreferredHour() async => null;

  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final CyclePrediction? Function() _prediction;

  /// The on-device learned "hour the user usually logs" (p4.2), or `null` when
  /// history is thin. Applied to the event-relative kinds only; recomputed on
  /// each call, never stored.
  final Future<int?> Function() _preferredHour;
  final DateTime Function() _now;

  /// Used the first time a reminder is turned on without a picked time — a
  /// neutral mid-morning default. Event-relative kinds prefer p4.2's learned
  /// hour when there is one, then fall back to this.
  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  Future<ReminderSchedule> _currentOrFallback(ReminderKind kind) async =>
      await _repository.get(kind) ??
      ReminderSchedule(
        kind: kind,
        hour: defaultHour,
        minute: defaultMinute,
        enabled: false,
      );

  /// Turn the reminder for [kind] on or off. Turning it on first asks for
  /// notification permission, then schedules; turning it off cancels only [kind].
  Future<void> setEnabled(ReminderKind kind, {required bool enabled}) async {
    final next = (await _currentOrFallback(kind)).copyWith(enabled: enabled);

    if (enabled) {
      await _scheduler.ensurePermission();
      await _repository.save(next);
      await _apply(next);
    } else {
      await _repository.save(next);
      await _scheduler.cancel(kind);
    }
  }

  /// Change the time of day [kind] fires. Reschedules only when [kind] is
  /// currently enabled.
  Future<void> setTime(
    ReminderKind kind, {
    required int hour,
    required int minute,
  }) async {
    final next = (await _currentOrFallback(
      kind,
    )).copyWith(hour: hour, minute: minute);
    await _repository.save(next);
    if (next.enabled) await _apply(next);
  }

  /// Hand an enabled [schedule] to the scheduler: daily for fixed-time kinds,
  /// a computed one-shot for forecast-anchored kinds (or a cancel when there is
  /// nothing to schedule yet).
  Future<void> _apply(ReminderSchedule schedule) async {
    if (!isEventRelativeReminder(schedule.kind)) {
      await _scheduler.scheduleDaily(schedule);
      return;
    }
    final when = nextFireTime(
      kind: schedule.kind,
      schedule: schedule,
      prediction: _prediction(),
      today: _now(),
      overrideHour: await _preferredHour(),
    );
    if (when != null) {
      await _scheduler.scheduleAt(schedule.kind, when);
    } else {
      await _scheduler.cancel(schedule.kind);
    }
  }
}
