import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_controller.dart';
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

  ReminderController controllerWith({
    CyclePrediction? forecast,
    int? preferredHour,
    QuietHours quietHours = kDefaultQuietHours,
    DateTime? now,
  }) => ReminderController(
    repo,
    scheduler,
    prediction: () => forecast,
    preferredHour: () async => preferredHour,
    quietHours: () async => quietHours,
    now: () => now ?? DateTime(2026, 3, 1, 8, 0),
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

    test(
      'a row already stored enabled (p1.7 upgrade) still schedules through the '
      'unified controller',
      () async {
        // Exactly what a p1.7 install left behind: an enabled medication row
        // at a custom time, written straight to the repo (no p4.x UI involved).
        await repo.save(
          const ReminderSchedule(
            kind: ReminderKind.medication,
            hour: 7,
            minute: 30,
            enabled: true,
          ),
        );

        // Re-applying it (Settings → Notifications with the row already on, or a
        // time tweak) goes through the same path as every other fixed kind.
        await controller.setEnabled(ReminderKind.medication, enabled: true);

        final daily = scheduler.scheduled.single;
        expect(daily.kind, ReminderKind.medication);
        expect((daily.hour, daily.minute), (7, 30));
        expect(daily.enabled, isTrue);
        expect(scheduler.oneShots, isEmpty);
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

  group('learned logging hour (p4.2)', () {
    test('an established logging hour overrides the default for an '
        'event-relative kind', () async {
      final controller = controllerWith(forecast: prediction, preferredHour: 6);

      await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

      // 2 days before the 20th, at the learned 06:00 — not the 09:00 default.
      expect(scheduler.oneShots.single.when, DateTime(2026, 3, 18, 6, 0));
    });

    test('the learned hour does NOT move a fixed-time kind', () async {
      final controller = controllerWith(forecast: prediction, preferredHour: 6);

      await controller.setEnabled(ReminderKind.medication, enabled: true);

      expect(scheduler.oneShots, isEmpty);
      final daily = scheduler.scheduled.single;
      expect(
        (daily.hour, daily.minute),
        (ReminderController.defaultHour, ReminderController.defaultMinute),
      );
    });

    test(
      'a null learned hour falls back to the stored / default time',
      () async {
        final controller = controllerWith(
          forecast: prediction,
          preferredHour: null,
        );

        await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

        expect(
          scheduler.oneShots.single.when,
          DateTime(2026, 3, 18, ReminderController.defaultHour, 0),
        );
      },
    );
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

  group('quiet hours (p4.4)', () {
    // 22:00 → 07:00, wrapping past midnight.
    const nightWindow = QuietHours(
      startHour: 22,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      enabled: true,
    );

    test(
      'an event-relative fire time inside the window is pushed to window end',
      () async {
        // Learned hour 23 lands the upcomingPeriod fire at 23:00 on 2026-03-18
        // — inside 22:00–07:00, so it shifts to 07:00 the next morning.
        final controller = controllerWith(
          forecast: prediction,
          preferredHour: 23,
          quietHours: nightWindow,
        );

        await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

        expect(scheduler.oneShots.single.when, DateTime(2026, 3, 19, 7, 0));
      },
    );

    test(
      'an event-relative fire time outside the window is untouched',
      () async {
        // Learned hour 9 → 09:00, comfortably outside 22:00–07:00.
        final controller = controllerWith(
          forecast: prediction,
          preferredHour: 9,
          quietHours: nightWindow,
        );

        await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

        expect(scheduler.oneShots.single.when, DateTime(2026, 3, 18, 9, 0));
      },
    );

    test(
      'a daily fixed-time kind inside the window fires at window end',
      () async {
        final controller = controllerWith(quietHours: nightWindow);
        await controller.setEnabled(ReminderKind.medication, enabled: true);
        scheduler.scheduled.clear();

        // 23:30 is inside 22:00–07:00 → the daily reminder is shifted to 07:00.
        await controller.setTime(ReminderKind.medication, hour: 23, minute: 30);

        final daily = scheduler.scheduled.single;
        expect((daily.hour, daily.minute), (7, 0));
        // The stored preference keeps the user's chosen time; only delivery moves.
        final stored = await repo.get(ReminderKind.medication);
        expect((stored!.hour, stored.minute), (23, 30));
      },
    );

    test('a daily fixed-time kind outside the window keeps its time', () async {
      final controller = controllerWith(quietHours: nightWindow);
      await controller.setEnabled(ReminderKind.medication, enabled: true);
      scheduler.scheduled.clear();

      await controller.setTime(ReminderKind.medication, hour: 8, minute: 15);

      final daily = scheduler.scheduled.single;
      expect((daily.hour, daily.minute), (8, 15));
    });

    test('a disabled window never shifts anything', () async {
      final controller = controllerWith(
        forecast: prediction,
        preferredHour: 23,
        quietHours: nightWindow.copyWith(enabled: false),
      );

      await controller.setEnabled(ReminderKind.upcomingPeriod, enabled: true);

      expect(scheduler.oneShots.single.when, DateTime(2026, 3, 18, 23, 0));
    });
  });
}
