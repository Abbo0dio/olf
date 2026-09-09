import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/conflict_review_screen.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../health/conflict_fixtures.dart';
import '../support/harness.dart';

/// r4 — the "Data & sharing" screen: the rows that move data in or out of olf,
/// pulled out of `settings_page.dart` so Settings holds only settings. Every
/// destination that used to sit on the flat Settings list must still be
/// reachable from here.
void main() {
  Future<void> openDataAndSharing(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data & sharing'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Data & sharing'), findsOneWidget);
  }

  testWidgets('reachable from Settings as a single row', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openDataAndSharing(tester);
      },
    );
  });

  testWidgets('Backup & restore opens from here', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openDataAndSharing(tester);
        await tester.tap(find.text('Backup & restore'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Backup & restore'), findsOneWidget);
      },
    );
  });

  testWidgets('Export report for a doctor opens from here', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openDataAndSharing(tester);
        await tester.tap(find.text('Export report for a doctor'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AppBar, 'Export report for a doctor'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('the health-platform block is absent without a platform', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openDataAndSharing(tester);
        expect(find.text('Connect a health app'), findsNothing);
        // The device-local rows are still here.
        expect(find.text('Backup & restore'), findsOneWidget);
        expect(find.text('Export report for a doctor'), findsOneWidget);
      },
    );
  });

  testWidgets('the "Connect a health app" tile shows when a platform exists', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
      ],
      body: () async {
        await openDataAndSharing(tester);
        await tester.scrollUntilVisible(
          find.text('Connect a health app'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Connect a health app'),
              )
              .value,
          isFalse,
        );
      },
    );
  });

  testWidgets('the "differences to review" row opens the review screen', (
    tester,
  ) async {
    final db = memoryDb();
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.appleHealthConnected, 'true');
    await DriftBbtRepository(db).setTemp(DateTime(2026, 5, 10), 36.4);
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
        healthConflictsProvider.overrideWith(
          seededConflicts([
            bbtConflict(DateTime(2026, 5, 10), local: 36.4, incoming: 36.9),
          ]),
        ),
      ],
      body: () async {
        await openDataAndSharing(tester);
        await tester.scrollUntilVisible(
          find.textContaining('to review'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.textContaining('to review'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(AppBar, ConflictReviewScreen.title),
          findsOneWidget,
        );
      },
    );
  });
}
