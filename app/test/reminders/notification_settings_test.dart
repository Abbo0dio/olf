import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_providers.dart';
import 'package:olf_app/src/reminders/notifications_page.dart';
import 'package:olf_app/src/reminders/reminder_copy.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late DriftReminderRepository repo;
  late FakeReminderScheduler scheduler;

  final prediction = CyclePrediction(
    nextPeriod: DateRange(DateTime(2026, 3, 18), DateTime(2026, 3, 22)),
    nextPeriodExpected: DateTime(2026, 3, 20),
    fertileWindow: DateRange(DateTime(2026, 3, 6), DateTime(2026, 3, 12)),
    confidence: PredictionConfidence.medium,
    basedOnCycles: 6,
    status: PredictionStatus.upcoming,
    daysPastExpected: null,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftReminderRepository(db);
    scheduler = FakeReminderScheduler();
  });
  tearDown(() => db.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    CyclePrediction? forecast,
    int? learnedHour,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          predictionProvider.overrideWithValue(forecast),
          preferredHourProvider.overrideWith((ref) async => learnedHour),
        ],
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// Dispose the tree and pump once more so drift's stream-close timer fires
  /// before the binding's pending-timer check (mirrors `pumpOlf`'s teardown).
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('one switch per category, all off by default', (tester) async {
    await pumpPage(tester, forecast: prediction);

    expect(
      find.byType(SwitchListTile),
      findsNWidgets(reminderCategoryOrder.length),
    );
    for (final kind in reminderCategoryOrder) {
      expect(find.text(reminderCategoryTitle(kind)), findsOneWidget);
      final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, reminderCategoryTitle(kind)),
      );
      expect(sw.value, isFalse);
    }

    await disposeTree(tester);
  });

  testWidgets('toggling one category leaves every other stored row untouched', (
    tester,
  ) async {
    await pumpPage(tester, forecast: prediction);

    await tester.tap(
      find.widgetWithText(
        SwitchListTile,
        reminderCategoryTitle(ReminderKind.medication),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect((await repo.get(ReminderKind.medication))!.enabled, isTrue);
    for (final kind in ReminderKind.values) {
      if (kind == ReminderKind.medication) continue;
      expect(
        await repo.get(kind),
        isNull,
        reason: 'toggling medication wrote a $kind row',
      );
    }

    await disposeTree(tester);
  });

  testWidgets(
    'an event-relative category with no forecast shows the "await history" '
    'affordance, not a time',
    (tester) async {
      await pumpPage(tester); // forecast == null

      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          reminderCategoryTitle(ReminderKind.upcomingPeriod),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.textContaining('enough logged history'), findsOneWidget);
      // No time row rendered for it.
      expect(find.widgetWithText(ListTile, 'Time'), findsNothing);

      await disposeTree(tester);
    },
  );

  testWidgets('a fixed-time category shows a Time row once enabled', (
    tester,
  ) async {
    await pumpPage(tester, forecast: prediction);

    await tester.tap(
      find.widgetWithText(
        SwitchListTile,
        reminderCategoryTitle(ReminderKind.medication),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.widgetWithText(ListTile, 'Time'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets(
    'an event-relative category with a learned hour shows the effective time '
    'read-only, no picker (p4.2)',
    (tester) async {
      await pumpPage(tester, forecast: prediction, learnedHour: 14);

      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          reminderCategoryTitle(ReminderKind.upcomingPeriod),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // The effective learned time is shown, and it is not the manual picker.
      final effective = const TimeOfDay(
        hour: 14,
        minute: 0,
      ).format(tester.element(find.byType(NotificationsPage)));
      expect(find.text('Around $effective'), findsOneWidget);
      expect(find.text('Timed to when you usually log'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Time'), findsNothing);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'an event-relative category with no learned hour keeps a picker + interim '
    'caption (p4.2)',
    (tester) async {
      await pumpPage(tester, forecast: prediction); // learnedHour == null

      await tester.tap(
        find.widgetWithText(
          SwitchListTile,
          reminderCategoryTitle(ReminderKind.fertileWindow),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.widgetWithText(ListTile, 'Time'), findsOneWidget);
      expect(find.textContaining("logged enough"), findsOneWidget);
      expect(find.text('Timed to when you usually log'), findsNothing);

      await disposeTree(tester);
    },
  );
}
