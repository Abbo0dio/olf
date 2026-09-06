import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  Future<void> openModesPage(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Life-stage & condition modes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Life-stage & condition modes'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Modes'), findsOneWidget);
  }

  testWidgets('every Phase 7 mode is listed, each off by default', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openModesPage(tester);
        expect(find.byType(SwitchListTile), findsNWidgets(8));
        for (final s in tester.widgetList<SwitchListTile>(
          find.byType(SwitchListTile),
        )) {
          expect(s.value, isFalse);
        }
        expect(find.text('Postpartum'), findsOneWidget);
        expect(find.text('PMDD'), findsOneWidget);
      },
    );
  });

  testWidgets('a mode toggles on and off, and logged data survives', (
    tester,
  ) async {
    final db = memoryDb();
    // Some data that must be untouched by flipping a mode.
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: daysAgo(10), end: daysAgo(6)));

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openModesPage(tester);
        final pmddSwitch = find.widgetWithText(SwitchListTile, 'PMDD');
        expect(tester.widget<SwitchListTile>(pmddSwitch).value, isFalse);

        await tester.tap(pmddSwitch);
        await tester.pumpAndSettle();
        expect(
          lifeStageModeEnabled(
            await DriftSettingsRepository(db).get('mode.pmdd'),
          ),
          isTrue,
        );

        await tester.tap(pmddSwitch);
        await tester.pumpAndSettle();
        expect(
          lifeStageModeEnabled(
            await DriftSettingsRepository(db).get('mode.pmdd'),
          ),
          isFalse,
        );

        // The period is still there.
        expect(await DriftPeriodRepository(db).allPeriods(), hasLength(1));
      },
    );
  });

  testWidgets('enabling pregnancy reveals a way into its screen', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openModesPage(tester);
        await tester.tap(find.widgetWithText(SwitchListTile, 'Pregnancy'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Open Pregnancy'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Open Pregnancy'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Pregnancy'), findsOneWidget);
      },
    );
  });

  testWidgets('enabling postpartum reveals a way into its screen', (
    tester,
  ) async {
    final db = memoryDb();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openModesPage(tester);
        await tester.tap(find.widgetWithText(SwitchListTile, 'Postpartum'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Open Postpartum'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Open Postpartum'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Postpartum'), findsOneWidget);
      },
    );
  });
}
