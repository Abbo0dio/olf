import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final tile = find.widgetWithText(SwitchListTile, 'Connect Apple Health');

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToTile(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Connect Apple Health'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  final day = DateTime(2026, 5, 10);

  HealthSample bbtSample(double celsius, String id) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: day,
    value: celsius,
    unit: HealthUnit.celsius,
    source: HealthDataSource.appleHealth,
    externalId: id,
  );

  testWidgets('the tile is hidden when no health platform is available', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);
        expect(find.text('Apps & export'), findsNothing);
        expect(find.text('Connect Apple Health'), findsNothing);
      },
    );
  });

  testWidgets('default state is off', (tester) async {
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToTile(tester);
        expect(find.text('Apps & export'), findsOneWidget);
        expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      },
    );
  });

  testWidgets('the opt-in dialog names both directions', (tester) async {
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToTile(tester);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('In — entries already in Apple Health'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Out — what you log in olf'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'Connect'), findsOneWidget);
      },
    );
  });

  testWidgets('granting runs the import and shows a plain summary', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    final bbt = DriftBbtRepository(db);

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(seedSamples: [bbtSample(36.7, 't1')]),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToTile(tester);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Connect'));
        await flush(tester, 50);

        expect(find.text('Apple Health connected'), findsOneWidget);
        expect(find.textContaining('Added 1, updated 0'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'OK'));
        await flush(tester, 20);

        expect(await settings.get(SettingKeys.appleHealthConnected), 'true');
        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 36.7);
        expect(row.source, 'appleHealth');
      },
    );
  });

  testWidgets('a refused permission sheet leaves the bridge off with a calm '
      'message', (tester) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(authOutcome: HealthAuthStatus.denied),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToTile(tester);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Connect'));
        await flush(tester, 50);

        expect(
          find.textContaining('Apple Health access was not granted'),
          findsOneWidget,
        );
        expect(tester.widget<SwitchListTile>(tile).value, isFalse);
        expect(await settings.get(SettingKeys.appleHealthConnected), isNull);
      },
    );
  });

  testWidgets('reduce spoken detail redacts the sync summary for screen '
      'readers', (tester) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await settings.set(SettingKeys.reduceSpokenDetail, 'true');
    await settings.set(SettingKeys.appleHealthConnected, 'true');
    await settings.set(SettingKeys.appleHealthLastSync, '2,1,0');

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToTile(tester);

        final subtitle = find.textContaining('Last sync: added 2, updated 1');
        expect(subtitle, findsOneWidget);
        expect(
          tester.widget<Text>(subtitle).semanticsLabel,
          'Apple Health is connected.',
        );
      },
    );
  });
}
