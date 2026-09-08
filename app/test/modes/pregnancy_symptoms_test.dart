import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/pregnancy_symptoms.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();

  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  group('curated list', () {
    test(
      'is a short, plain, de-duplicated name set within the length limit',
      () {
        expect(kPregnancySymptomNames, isNotEmpty);
        expect(kPregnancySymptomNames.length, lessThanOrEqualTo(20));

        for (final name in kPregnancySymptomNames) {
          expect(
            name.trim(),
            name,
            reason: '"$name" has surrounding whitespace',
          );
          expect(name, isNotEmpty);
          expect(
            name.length,
            lessThanOrEqualTo(maxSymptomNameLength),
            reason: '"$name" is longer than a symptom name may be',
          );
        }

        final lower = kPregnancySymptomNames
            .map((n) => n.toLowerCase())
            .toList();
        expect(
          lower.toSet(),
          hasLength(lower.length),
          reason: 'curated names must be unique (case-insensitively)',
        );
      },
    );

    test(
      'reuses at least one existing built-in name rather than forking it',
      () {
        final builtInLower = kBuiltInSymptomNames.map((n) => n.toLowerCase());
        final curatedLower = kPregnancySymptomNames.map((n) => n.toLowerCase());
        expect(
          curatedLower.toSet().intersection(builtInLower.toSet()),
          isNotEmpty,
        );
      },
    );
  });

  Future<void> openScreen(WidgetTester tester) async {
    // r3b: the Modes on/off entry moved from Settings to the Patterns tab.
    await switchTab(tester, 'Patterns');
    await tester.scrollUntilVisible(
      find.text('Life-stage & condition modes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Life-stage & condition modes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open Pregnancy'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open Pregnancy'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log pregnancy symptoms'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Log pregnancy symptoms'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Pregnancy symptoms'), findsOneWidget);
  }

  Future<void> seedPregnancyMode(AppDatabase db) async {
    await DriftSettingsRepository(
      db,
    ).set(LifeStageMode.pregnancy.settingKey, 'true');
  }

  testWidgets(
    'tapping a curated chip adds it to the catalogue and logs today',
    (tester) async {
      final db = memoryDb();
      await seedPregnancyMode(db);
      final repo = DriftSymptomRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openScreen(tester);

          // "Nausea" is not a built-in — tapping it creates it, then logs it.
          await tester.ensureVisible(chip('Nausea'));
          await tester.tap(chip('Nausea'));
          await tester.pumpAndSettle();

          final types = await repo.activeTypes();
          final nausea = types.firstWhere((t) => t.name == 'Nausea');
          expect(await repo.symptomsOn(today), contains(nausea.id));
        },
      );
    },
  );

  testWidgets('a curated name matching a built-in reuses that row (no dup)', (
    tester,
  ) async {
    final db = memoryDb();
    await seedPregnancyMode(db);
    final repo = DriftSymptomRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openScreen(tester);

        await tester.ensureVisible(chip('Chest tenderness'));
        await tester.tap(chip('Chest tenderness'));
        await tester.pumpAndSettle();

        final matches = (await repo.activeTypes())
            .where((t) => t.name == 'Chest tenderness')
            .toList();
        expect(matches, hasLength(1));
        expect(await repo.symptomsOn(today), contains(matches.single.id));
      },
    );
  });

  testWidgets('tapping a selected chip again clears it for today', (
    tester,
  ) async {
    final db = memoryDb();
    await seedPregnancyMode(db);
    final repo = DriftSymptomRepository(db);
    final headache = (await repo.activeTypes())
        .firstWhere((t) => t.name == 'Headache')
        .id;
    await repo.setSymptom(today, headache, present: true);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openScreen(tester);

        // "Headache" is a built-in and already logged — the chip shows selected.
        expect(await repo.symptomsOn(today), contains(headache));
        await tester.ensureVisible(chip('Headache'));
        await tester.tap(chip('Headache'));
        await tester.pumpAndSettle();
        expect(await repo.symptomsOn(today), isNot(contains(headache)));
      },
    );
  });
}
