import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seedOldPeriod(AppDatabase db) => DriftPeriodRepository(
    db,
  ).addPeriod(PeriodDraft(start: daysAgo(900), end: daysAgo(896)));

  Future<void> seedRecentPeriod(AppDatabase db) => DriftPeriodRepository(
    db,
  ).addPeriod(PeriodDraft(start: daysAgo(10), end: daysAgo(6)));

  Future<void> setWindow(AppDatabase db, RetentionWindow w) =>
      DriftSettingsRepository(db).set(SettingKeys.retentionWindow, w.name);

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  final retentionRow = find.widgetWithText(ListTile, 'Auto-delete old entries');

  testWidgets('startup sweep purges entries older than the saved window', (
    tester,
  ) async {
    final db = memoryDb();
    await seedOldPeriod(db);
    await seedRecentPeriod(db);
    await setWindow(db, RetentionWindow.year1);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 25);

        final periods = await db.select(db.periods).get();
        expect(periods, hasLength(1));
        expect(periods.single.startDate, daysAgo(10));
        expect(
          find.text(formatRange(daysAgo(900), daysAgo(896))),
          findsNothing,
        );
      },
    );
  });

  testWidgets('no window set → the startup sweep keeps everything', (
    tester,
  ) async {
    final db = memoryDb();
    await seedOldPeriod(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await flush(tester, 25);
        expect(await db.select(db.periods).get(), hasLength(1));
      },
    );
  });

  testWidgets('the settings row shows Off by default', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);
        expect(retentionRow, findsOneWidget);
        expect(
          find.descendant(of: retentionRow, matching: find.text('Off')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets(
    'picking a window: confirm → setting persists and old entries are purged',
    (tester) async {
      final db = memoryDb();
      final settings = DriftSettingsRepository(db);
      await seedOldPeriod(db);
      await seedRecentPeriod(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openSettings(tester);
          await tester.tap(retentionRow);
          await tester.pumpAndSettle();

          await tester.tap(
            find.widgetWithText(
              RadioListTile<RetentionWindow>,
              RetentionWindow.year1.label,
            ),
          );
          await tester.pumpAndSettle();

          // Confirmation step before anything is deleted.
          expect(find.text('Delete older entries now?'), findsOneWidget);
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
          await flush(tester, 25);

          expect(await settings.get(SettingKeys.retentionWindow), 'year1');
          final periods = await db.select(db.periods).get();
          expect(periods, hasLength(1));
          expect(periods.single.startDate, daysAgo(10));
          expect(
            find.text('Old entries will be cleaned up automatically.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  testWidgets('picking a window: cancel the confirmation → nothing changes', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await seedOldPeriod(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openSettings(tester);
        await tester.tap(retentionRow);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            RadioListTile<RetentionWindow>,
            RetentionWindow.years2.label,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await flush(tester, 20);

        expect(await settings.get(SettingKeys.retentionWindow), isNull);
        expect(await db.select(db.periods).get(), hasLength(1));
      },
    );
  });

  testWidgets('turning the window back Off needs no confirmation', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await setWindow(db, RetentionWindow.year1);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openSettings(tester);
        await tester.tap(retentionRow);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            RadioListTile<RetentionWindow>,
            'Off — keep everything',
          ),
        );
        await flush(tester, 20);

        expect(find.text('Delete older entries now?'), findsNothing);
        expect(await settings.get(SettingKeys.retentionWindow), 'off');
        expect(find.text('Auto-delete turned off.'), findsOneWidget);
      },
    );
  });
}
