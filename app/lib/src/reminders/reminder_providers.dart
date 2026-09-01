import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../prediction/prediction_providers.dart';
import '../providers.dart';
import 'local_notification_reminder_scheduler.dart';
import 'reminder_controller.dart';
import 'reminder_scheduler.dart';

/// The OS-notification wrapper. Overridden with a fake in tests; the production
/// value never touches a platform channel until a method is called.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationReminderScheduler.instance,
);

/// Stored-reminder CRUD over the opened database. Only valid inside the `data`
/// branch of the database gate (see [appDatabaseProvider]).
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftReminderRepository(db);
});

/// The stored schedule for one [ReminderKind], live (`null` until first set).
final reminderScheduleProvider = StreamProvider.family
    .autoDispose<ReminderSchedule?, ReminderKind>((ref, kind) {
      return ref.watch(reminderRepositoryProvider).watch(kind);
    });

/// The stored daily medication reminder, live. p1.7's meds page still listens to
/// this; it is folded away in p4.6.
final medicationReminderProvider = StreamProvider<ReminderSchedule?>((ref) {
  return ref.watch(reminderRepositoryProvider).watch(ReminderKind.medication);
});

/// Keeps a stored reminder and its OS notification in step, for any kind.
final reminderControllerProvider = Provider<ReminderController>((ref) {
  return ReminderController(
    ref.watch(reminderRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
    prediction: () => ref.read(predictionProvider),
  );
});

/// Re-plans the forecast-anchored reminders whenever the forecast moves, and
/// once at start-up.
///
/// Watched by `HomePage` so it lives for the whole data session. Logging or
/// editing a period changes [predictionProvider], which re-fires the listener
/// and re-arms `upcomingPeriod` / `fertileWindow` / `latePeriodCheckIn` with no
/// user action. Fixed-time kinds are never touched here.
class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;

  static const List<ReminderKind> _kinds = [
    ReminderKind.upcomingPeriod,
    ReminderKind.fertileWindow,
    ReminderKind.latePeriodCheckIn,
  ];

  Future<void> replan([CyclePrediction? prediction]) async {
    final forecast = prediction ?? _ref.read(predictionProvider);
    final repo = _ref.read(reminderRepositoryProvider);
    final scheduler = _ref.read(reminderSchedulerProvider);

    for (final kind in _kinds) {
      final schedule = await repo.get(kind);
      if (schedule == null || !schedule.enabled) continue;
      final when = nextFireTime(
        kind: kind,
        schedule: schedule,
        prediction: forecast,
        today: DateTime.now(),
      );
      if (when != null) {
        await scheduler.scheduleAt(kind, when);
      } else {
        await scheduler.cancel(kind);
      }
    }
  }
}

/// Wire the sync and run the start-up pass. `HomePage` watches this.
///
/// Guards on the encrypted database being open — a missing key is a deliberate
/// dead-end (see [appDatabaseProvider]) and the forecast providers throw before
/// that. Rebuilds and wires up once the `data` branch is reached.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  if (ref.watch(appDatabaseProvider) is AsyncData) {
    ref.listen<CyclePrediction?>(
      predictionProvider,
      (_, next) => sync.replan(next),
      fireImmediately: true,
    );
  }
  return sync;
});
