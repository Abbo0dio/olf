import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/birth_control_recalibration_content.dart';
import 'package:olf_app/src/modes/birth_control_recalibration_screen.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  Future<void> seedStart(AppDatabase db, DateTime start) =>
      DriftPeriodRepository(db).addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );

  /// A regular five-period history so the forecast card renders when nothing
  /// suppresses it.
  Future<void> seedRegularHistory(AppDatabase db) async {
    for (final ago in const [132, 104, 76, 48, 20]) {
      await seedStart(db, daysAgo(ago));
    }
  }

  const note = BirthControlRecalibrationContent.predictionCardNote;

  testWidgets(
    'starting hormonal BC with the mode on withholds the forecast and shows '
    'the recalibration note',
    (tester) async {
      final db = memoryDb();
      await seedRegularHistory(db);
      final settings = DriftSettingsRepository(db);
      final bc = DriftBirthControlRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // Forecast is visible to begin with.
          expect(find.text('Next period'), findsOneWidget);

          // Turn the mode on and record starting the pill today.
          await settings.set(
            LifeStageMode.birthControlSwitch.settingKey,
            'true',
          );
          await bc.switchTo(BirthControlMethod.pill);
          await tester.pumpAndSettle();

          expect(find.text(note), findsOneWidget);
          expect(find.text('Next period'), findsNothing);
          expect(find.textContaining('Fertile window'), findsNothing);
        },
      );
    },
  );

  testWidgets('the note is not shown while the mode is off', (tester) async {
    final db = memoryDb();
    await seedRegularHistory(db);
    await DriftBirthControlRepository(db).switchTo(BirthControlMethod.pill);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        expect(find.text(note), findsNothing);
        expect(find.text('Next period'), findsOneWidget);
      },
    );
  });

  testWidgets('a non-hormonal method does not trigger the note', (
    tester,
  ) async {
    final db = memoryDb();
    await seedRegularHistory(db);
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await settings.set(LifeStageMode.birthControlSwitch.settingKey, 'true');
        await DriftBirthControlRepository(
          db,
        ).switchTo(BirthControlMethod.condom);
        await tester.pumpAndSettle();

        expect(find.text(note), findsNothing);
        expect(find.text('Next period'), findsOneWidget);
      },
    );
  });

  testWidgets('Learn more opens the guided explainer', (tester) async {
    final db = memoryDb();
    await seedRegularHistory(db);
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await settings.set(LifeStageMode.birthControlSwitch.settingKey, 'true');
        await DriftBirthControlRepository(db).switchTo(BirthControlMethod.pill);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Learn more'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AppBar, 'After a birth-control change'),
          findsOneWidget,
        );
        expect(find.text('If you just started'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(BirthControlRecalibrationContent.notMedicalDeviceLine),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(BirthControlRecalibrationContent.notMedicalDeviceLine),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('dismissing the note restores the forecast', (tester) async {
    final db = memoryDb();
    await seedRegularHistory(db);
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await settings.set(LifeStageMode.birthControlSwitch.settingKey, 'true');
        await DriftBirthControlRepository(db).switchTo(BirthControlMethod.pill);
        await tester.pumpAndSettle();
        expect(find.text(note), findsOneWidget);

        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();

        expect(find.text(note), findsNothing);
        expect(find.text('Next period'), findsOneWidget);
      },
    );
  });

  testWidgets('the note auto-clears once the window has elapsed', (
    tester,
  ) async {
    final db = memoryDb();
    await seedRegularHistory(db);
    final settings = DriftSettingsRepository(db);
    final bc = DriftBirthControlRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await settings.set(LifeStageMode.birthControlSwitch.settingKey, 'true');
        // Started well over the 90-day window ago.
        await bc.switchTo(BirthControlMethod.pill, startedOn: daysAgo(200));
        await tester.pumpAndSettle();

        expect(find.text(note), findsNothing);
        expect(find.text('Next period'), findsOneWidget);
      },
    );
  });

  testWidgets('explainer screen has the disclaimer and a real-care line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: olfTheme(Brightness.light),
        home: const BirthControlRecalibrationScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('doctor'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('doctor'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text(BirthControlRecalibrationContent.notMedicalDeviceLine),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(BirthControlRecalibrationContent.notMedicalDeviceLine),
      findsOneWidget,
    );
  });

  test('no bundled recalibration text contains a phone-home URL', () {
    const c = birthControlRecalibrationContent;
    final blob = [
      c.title,
      c.intro,
      c.findCareLine,
      BirthControlRecalibrationContent.predictionCardNote,
      for (final s in c.sections) '${s.heading} ${s.body}',
    ].join(' ');
    expect(blob.contains('http'), isFalse);
    expect(blob.contains('www.'), isFalse);
  });
}
