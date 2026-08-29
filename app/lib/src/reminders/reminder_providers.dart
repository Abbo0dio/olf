import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

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

/// The stored daily medication reminder, live (`null` until first set). Not
/// `autoDispose` — the meds screen listens; same reasoning as the other
/// home-area streams.
final medicationReminderProvider = StreamProvider<ReminderSchedule?>((ref) {
  return ref.watch(reminderRepositoryProvider).watch(ReminderKind.medication);
});

/// Keeps the stored reminder and the OS notification in step.
final reminderControllerProvider = Provider<ReminderController>((ref) {
  return ReminderController(
    ref.watch(reminderRepositoryProvider),
    ref.watch(reminderSchedulerProvider),
  );
});
