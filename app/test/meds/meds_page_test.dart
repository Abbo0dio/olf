import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/harness.dart';

void main() {
  Future<void> openMeds(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Medications'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Medications'), findsOneWidget);
  }

  testWidgets('add a medication → it shows in the list and is stored', (
    tester,
  ) async {
    final db = memoryDb();
    final fake = FakeReminderScheduler();

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reminderSchedulerProvider.overrideWithValue(fake),
      ],
      body: () async {
        await openMeds(tester);

        await tester.tap(find.text('Add medication'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Iron');
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('Iron'), findsOneWidget);
        final stored = await DriftMedicationRepository(db).activeMedications();
        expect(stored.single.name, 'Iron');
      },
    );
  });

  testWidgets('set a birth-control method → it shows as current', (
    tester,
  ) async {
    final db = memoryDb();
    final fake = FakeReminderScheduler();

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reminderSchedulerProvider.overrideWithValue(fake),
      ],
      body: () async {
        await openMeds(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Set'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Pill'));
        await tester.pumpAndSettle();

        expect(find.text('Pill'), findsOneWidget);
        expect(find.textContaining('Since '), findsOneWidget);
        expect(
          (await DriftBirthControlRepository(db).current())!.method,
          BirthControlMethod.pill,
        );
      },
    );
  });

  testWidgets(
    'the daily-reminder controls have moved out — no reminder UI here (p4.6)',
    (tester) async {
      final db = memoryDb();
      final fake = FakeReminderScheduler();

      await pumpOlf(
        tester,
        overrides: [
          dbOverride(db),
          reminderSchedulerProvider.overrideWithValue(fake),
        ],
        body: () async {
          await openMeds(tester);

          // The p1.7 "Daily reminder" section is gone; it lives in
          // Settings → Notifications now.
          expect(find.text('Daily reminder'), findsNothing);
          expect(find.text('Remind me once a day'), findsNothing);
          expect(find.byType(SwitchListTile), findsNothing);
          // The other sections still render.
          expect(find.text('Birth control'), findsOneWidget);
          expect(find.text('Add medication'), findsOneWidget);
        },
      );
    },
  );
}
