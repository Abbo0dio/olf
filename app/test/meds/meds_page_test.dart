import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/harness.dart';

void main() {
  Future<void> openMeds(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Medications & reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Medications & reminders'), findsOneWidget);
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

  testWidgets('turning the reminder on schedules it and persists', (
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

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(fake.scheduled, isNotEmpty);
        expect(fake.scheduled.last.enabled, isTrue);

        final stored = await DriftReminderRepository(
          db,
        ).get(ReminderKind.medication);
        expect(stored!.enabled, isTrue);
      },
    );
  });
}
