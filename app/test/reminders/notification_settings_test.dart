import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_providers.dart';
import 'package:olf_app/src/reminders/notifications_page.dart';
import 'package:olf_app/src/reminders/quiet_hours_providers.dart';
import 'package:olf_app/src/reminders/reminder_copy.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_app/src/settings/settings_providers.dart';
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
    final settings = DriftSettingsRepository(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repo),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          predictionProvider.overrideWithValue(forecast),
          preferredHourProvider.overrideWith((ref) async => learnedHour),
          settingsRepositoryProvider.overrideWithValue(settings),
          // Bypass the database-gate branch in the real provider; read the
          // in-memory settings store directly.
          quietHoursProvider.overrideWith(
            (ref) =>
                settings.watch(SettingKeys.quietHours).map(decodeQuietHours),
          ),
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

    // One switch per category, plus the app-wide Quiet hours switch (p4.4).
    expect(
      find.byType(SwitchListTile),
      findsNWidgets(reminderCategoryOrder.length + 1),
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
    'a medication reminder enabled before p4.6 surfaces here, on, at its '
    'stored time (upgrade path)',
    (tester) async {
      // A row exactly as a p1.7 install would have left it.
      await repo.save(
        const ReminderSchedule(
          kind: ReminderKind.medication,
          hour: 7,
          minute: 30,
          enabled: true,
        ),
      );

      await pumpPage(tester, forecast: prediction);

      final medSwitch = find.widgetWithText(
        SwitchListTile,
        reminderCategoryTitle(ReminderKind.medication),
      );
      expect(tester.widget<SwitchListTile>(medSwitch).value, isTrue);
      expect(find.widgetWithText(ListTile, 'Time'), findsOneWidget);
      expect(
        find.text(
          const TimeOfDay(
            hour: 7,
            minute: 30,
          ).format(tester.element(find.byType(NotificationsPage))),
        ),
        findsOneWidget,
      );

      await disposeTree(tester);
    },
  );

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

  group('quiet hours (p4.4)', () {
    testWidgets('off by default — a switch, no time rows', (tester) async {
      await pumpPage(tester, forecast: prediction);

      final sw = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Quiet hours'),
      );
      expect(sw.value, isFalse);
      expect(find.widgetWithText(ListTile, 'Start'), findsNothing);
      expect(find.widgetWithText(ListTile, 'End'), findsNothing);

      await disposeTree(tester);
    });

    testWidgets('enabling persists the window and reveals both ends', (
      tester,
    ) async {
      final settings = DriftSettingsRepository(db);
      await pumpPage(tester, forecast: prediction);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Quiet hours'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Both ends are now editable...
      expect(find.widgetWithText(ListTile, 'Start'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'End'), findsOneWidget);
      // ...and the enabled window is written straight through to the KV store.
      expect(
        decodeQuietHours(await settings.get(SettingKeys.quietHours)),
        kDefaultQuietHours.copyWith(enabled: true),
      );

      await disposeTree(tester);
    });

    testWidgets('tapping an end opens a time picker wired to the store', (
      tester,
    ) async {
      final settings = DriftSettingsRepository(db);
      await settings.set(
        SettingKeys.quietHours,
        encodeQuietHours(kDefaultQuietHours.copyWith(enabled: true)),
      );
      await pumpPage(tester, forecast: prediction);
      await tester.pump(const Duration(milliseconds: 20));

      final startRow = find.widgetWithText(ListTile, 'Start');
      await tester.ensureVisible(startRow);
      await tester.pump();
      await tester.tap(startRow);
      await tester.pumpAndSettle();

      // A real time picker is up (its action buttons are present)...
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // ...and confirming it routes back through the controller to the store
      // (initial time unchanged, but the whole save path is exercised).
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        decodeQuietHours(await settings.get(SettingKeys.quietHours)),
        kDefaultQuietHours.copyWith(enabled: true),
      );

      await disposeTree(tester);
    });
  });
}
