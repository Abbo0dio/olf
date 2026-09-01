import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_controller.dart';
import 'package:olf_app/src/reminders/reminder_copy.dart';
import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repo;
  late FakeReminderScheduler scheduler;

  // A forecast so the event-relative kinds have something to plan against.
  final prediction = CyclePrediction(
    nextPeriod: DateRange(DateTime(2026, 3, 18), DateTime(2026, 3, 22)),
    nextPeriodExpected: DateTime(2026, 3, 20),
    fertileWindow: DateRange(DateTime(2026, 3, 6), DateTime(2026, 3, 12)),
    confidence: PredictionConfidence.medium,
    basedOnCycles: 6,
    status: PredictionStatus.upcoming,
    daysPastExpected: null,
  );

  ReminderController controllerWith({CyclePrediction? forecast}) =>
      ReminderController(
        repo,
        scheduler,
        prediction: () => forecast,
        now: () => DateTime(2026, 3, 1, 8, 0),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    scheduler = FakeReminderScheduler();
  });
  tearDown(() => db.close());

  group('fixed-time kind (medication)', () {
    late ReminderController controller;
    setUp(() => controller = controllerWith());

    Future<ReminderSchedule?> stored() => repo.get(ReminderKind.medication);

    test(
      'enabling stores an enabled row and schedules it daily once',
      () async {
        await controller.setEnabled(ReminderKind.medication, enabled: true);

        final row = await stored();
        expect(row!.enabled, isTrue);
        expect(row.hour, ReminderController.defaultHour);
        expect(row.minute, ReminderController.defaultMinute);

        expect(scheduler.permissionRequests, 1);
        expect(scheduler.scheduled.single.kind, ReminderKind.medication);
        expect(scheduler.oneShots, isEmpty);
        expect(scheduler.cancelled, isEmpty);
      },
    );

    test('disabling stores a disabled row and cancels', () async {
      await controller.setEnabled(ReminderKind.medication, enabled: true);
      scheduler.scheduled.clear();

      await controller.setEnabled(ReminderKind.medication, enabled: false);

      expect((await stored())!.enabled, isFalse);
      expect(scheduler.cancelled, [ReminderKind.medication]);
      expect(scheduler.scheduled, isEmpty);
    });

    test('changing the time while enabled reschedules daily', () async {
      await controller.setEnabled(ReminderKind.medication, enabled: true);
      scheduler.scheduled.clear();

      await controller.setTime(ReminderKind.medication, hour: 21, minute: 30);

      final row = await stored();
      expect((row!.hour, row.minute), (21, 30));
      expect(row.enabled, isTrue);
      expect(scheduler.scheduled.single.hour, 21);
      expect(scheduler.scheduled.single.minute, 30);
    });

    test(
      'changing the time while disabled stores but does not schedule',
      () async {
        await controller.setTime(ReminderKind.medication, hour: 7, minute: 15);

        final row = await stored();
        expect((row!.hour, row.minute), (7, 15));
        expect(row.enabled, isFalse);
        expect(scheduler.scheduled, isEmpty);
        expect(scheduler.cancelled, isEmpty);
      },
    );
  });

  group('event-relative kind (with a forecast)', () {
    late ReminderController controller;
    setUp(() => controller = controllerWith(forecast: prediction));

    test(
      'enabling upcomingPeriod arms exactly one one-shot for that kind',
      () async {
        await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

        expect((await repo.get(ReminderKind.upcomingPeriod))!.enabled, isTrue);
        expect(scheduler.scheduled, isEmpty); // not a daily
        expect(scheduler.oneShots.single.kind, ReminderKind.upcomingPeriod);
        // 2 days before the 20th, at the default 09:00.
        expect(
          scheduler.oneShots.single.when,
          DateTime(2026, 3, 18, ReminderController.defaultHour, 0),
        );
      },
    );

    test('disabling cancels exactly that kind', () async {
      await controller.setEnabled(ReminderKind.fertileWindow, enabled: true);
      await controller.setEnabled(ReminderKind.fertileWindow, enabled: false);

      expect(scheduler.cancelled, contains(ReminderKind.fertileWindow));
      expect((await repo.get(ReminderKind.fertileWindow))!.enabled, isFalse);
    });
  });

  test('enabling a kind never schedules or cancels another kind', () async {
    final controller = controllerWith(forecast: prediction);

    await controller.setEnabled(ReminderKind.medication, enabled: true);
    await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

    // medication: one daily, its own kind only.
    expect(scheduler.scheduled.map((s) => s.kind), [ReminderKind.medication]);
    // upcomingPeriod: one one-shot, its own kind only.
    expect(scheduler.oneShots.map((o) => o.kind), [
      ReminderKind.upcomingPeriod,
    ]);
    // nothing was cancelled as a side effect.
    expect(scheduler.cancelled, isEmpty);
    // the other three kinds have no stored row.
    for (final kind in const [
      ReminderKind.fertileWindow,
      ReminderKind.bbtPrompt,
      ReminderKind.latePeriodCheckIn,
    ]) {
      expect(await repo.get(kind), isNull);
    }
  });

  test(
    'enabling an event-relative kind with no forecast stores but arms nothing',
    () async {
      final controller = controllerWith(); // forecast == null

      await controller.setEnabled(
        ReminderKind.latePeriodCheckIn,
        enabled: true,
      );

      expect((await repo.get(ReminderKind.latePeriodCheckIn))!.enabled, isTrue);
      expect(scheduler.oneShots, isEmpty);
      expect(scheduler.scheduled, isEmpty);
    },
  );

  // p2.4 lock-in: reminder text sits on a lock screen, so no kind's wording may
  // carry a health detail. Extends the p1.7 check to every category.
  test('no notification body for any kind carries a health detail', () {
    const banned = [
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
    ];
    for (final kind in ReminderKind.values) {
      final copy = notificationCopyFor(kind);
      final text = '${copy.title} ${copy.body}'.toLowerCase();
      expect(copy.body, isNotEmpty, reason: '$kind has an empty body');
      for (final word in banned) {
        expect(text, isNot(contains(word)), reason: '$kind leaks "$word"');
      }
    }
    // p1.7's exact strings are unchanged.
    expect(reminderNotificationBody, 'Time for your daily check-in.');
    expect(
      notificationCopyFor(ReminderKind.medication).body,
      reminderNotificationBody,
    );
  });
}
