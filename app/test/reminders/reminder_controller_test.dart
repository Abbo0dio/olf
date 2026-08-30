import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_controller.dart';
import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repo;
  late FakeReminderScheduler scheduler;
  late ReminderController controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    scheduler = FakeReminderScheduler();
    controller = ReminderController(repo, scheduler);
  });
  tearDown(() => db.close());

  Future<ReminderSchedule?> stored() => repo.get(ReminderKind.medication);

  test('enabling stores an enabled row and schedules it once', () async {
    await controller.setEnabled(enabled: true);

    final row = await stored();
    expect(row!.enabled, isTrue);
    expect(row.hour, ReminderController.defaultHour);
    expect(row.minute, ReminderController.defaultMinute);

    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.scheduled.single.enabled, isTrue);
    expect(scheduler.cancelled, isEmpty);
  });

  test('disabling stores a disabled row and cancels', () async {
    await controller.setEnabled(enabled: true);
    scheduler.scheduled.clear();

    await controller.setEnabled(enabled: false);

    expect((await stored())!.enabled, isFalse);
    expect(scheduler.cancelled, [ReminderKind.medication]);
    expect(scheduler.scheduled, isEmpty);
  });

  test(
    'changing the time while enabled reschedules with the new time',
    () async {
      await controller.setEnabled(enabled: true);
      scheduler.scheduled.clear();

      await controller.setTime(hour: 21, minute: 30);

      final row = await stored();
      expect((row!.hour, row.minute), (21, 30));
      expect(row.enabled, isTrue);
      expect(scheduler.scheduled.single.hour, 21);
      expect(scheduler.scheduled.single.minute, 30);
    },
  );

  test(
    'changing the time while disabled stores but does not schedule',
    () async {
      await controller.setTime(hour: 7, minute: 15);

      final row = await stored();
      expect((row!.hour, row.minute), (7, 15));
      expect(row.enabled, isFalse);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, isEmpty);
    },
  );

  // p2.4 lock-in: the reminder text sits on a lock screen / notification
  // shade, so it must never carry a health detail. Extends the p1.7 check.
  test('the notification wording carries no health details', () {
    final text = '$reminderNotificationTitle $reminderNotificationBody'
        .toLowerCase();
    for (final banned in const [
      'medication',
      'med ',
      'pill',
      'patch',
      'ring',
      'injection',
      'dose',
      'dosage',
      'birth control',
      'contracept',
      'iud',
      'implant',
      'period',
      'menstru',
      'cycle',
      'ovulat',
      'fertil',
      'flow',
      'bleed',
      'spotting',
      'cramp',
      'symptom',
      'mood',
      'pregnan',
      'temperature',
      'bbt',
      'mucus',
    ]) {
      expect(text, isNot(contains(banned)), reason: 'leaks "$banned"');
    }
    expect(reminderNotificationBody, isNotEmpty);
  });
}
