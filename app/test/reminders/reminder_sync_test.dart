import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/harness.dart';

/// p4.1 — the forecast-anchored reminders re-arm themselves when the forecast
/// moves, with no user action, and the fixed-time `medication` reminder is never
/// touched by that path. p4.2 — that re-plan also honours the learned logging
/// hour.
void main() {
  // "Today", so the seeded history produces a forecast that is genuinely in the
  // future (the planning module drops any instant already in the past).
  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  DateTime ago(int days) => d0.subtract(Duration(days: days));

  Future<void> seedRegularHistory(AppDatabase db) async {
    final periods = DriftPeriodRepository(db);
    for (final start in [ago(98), ago(70), ago(42), ago(14)]) {
      await periods.addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 4))),
      );
    }
  }

  testWidgets(
    'logging a period re-arms upcomingPeriod at a shifted instant and never '
    'touches the medication reminder',
    (tester) async {
      final db = memoryDb();
      final scheduler = FakeReminderScheduler();

      // A regular ~28-day history — three complete cycles, last start 14 days
      // ago, so the next period is expected ~2 weeks out.
      final periods = DriftPeriodRepository(db);
      await seedRegularHistory(db);

      // One event-relative category on, one fixed-time category on.
      final reminders = DriftReminderRepository(db);
      await reminders.save(
        const ReminderSchedule(
          kind: ReminderKind.upcomingPeriod,
          hour: 9,
          minute: 0,
          enabled: true,
        ),
      );
      await reminders.save(
        const ReminderSchedule(
          kind: ReminderKind.medication,
          hour: 8,
          minute: 0,
          enabled: true,
        ),
      );

      await pumpOlf(
        tester,
        overrides: [
          dbOverride(db),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        body: () async {
          // HomePage watches reminderSyncProvider → the start-up pass has run.
          await flush(tester);
          final first = scheduler.oneShotFor(ReminderKind.upcomingPeriod);
          expect(
            first,
            isNotNull,
            reason: 'the start-up pass armed upcomingPeriod',
          );
          final armedBefore = scheduler.oneShots.length;

          // Logging a period moves the forecast.
          await periods.addPeriod(PeriodDraft(start: ago(3), end: ago(1)));
          await flush(tester);

          final second = scheduler.oneShotFor(ReminderKind.upcomingPeriod);
          expect(second, isNotNull);
          expect(
            scheduler.oneShots.length,
            greaterThan(armedBefore),
            reason: 'the forecast change re-armed the one-shot',
          );
          expect(
            second,
            isNot(first),
            reason: 'the re-armed instant moved with the forecast',
          );

          // The sync path must never schedule or cancel a fixed-time kind.
          expect(
            scheduler.scheduled,
            isEmpty,
            reason: 'sync never calls scheduleDaily',
          );
          expect(scheduler.cancelled, isNot(contains(ReminderKind.medication)));
          expect(
            scheduler.oneShots.map((o) => o.kind),
            everyElement(isNot(ReminderKind.medication)),
          );
        },
      );
    },
  );

  testWidgets(
    'an established logging hour re-plans upcomingPeriod at that hour, and '
    'never touches the medication reminder',
    (tester) async {
      final db = memoryDb();
      final scheduler = FakeReminderScheduler();

      await seedRegularHistory(db);
      final reminders = DriftReminderRepository(db);
      await reminders.save(
        const ReminderSchedule(
          kind: ReminderKind.upcomingPeriod,
          hour: 9,
          minute: 0,
          enabled: true,
        ),
      );
      await reminders.save(
        const ReminderSchedule(
          kind: ReminderKind.medication,
          hour: 8,
          minute: 0,
          enabled: true,
        ),
      );

      await pumpOlf(
        tester,
        overrides: [
          dbOverride(db),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          preferredHourProvider.overrideWith((ref) async => 6),
        ],
        body: () async {
          await flush(tester);

          final armed = scheduler.oneShotFor(ReminderKind.upcomingPeriod);
          expect(armed, isNotNull, reason: 'the start-up pass armed it');
          expect(
            (armed!.hour, armed.minute),
            (6, 0),
            reason: 'fired at the learned 06:00, not the stored 09:00',
          );

          expect(scheduler.scheduled, isEmpty);
          expect(scheduler.cancelled, isNot(contains(ReminderKind.medication)));
        },
      );
    },
  );
}
