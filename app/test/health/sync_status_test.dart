import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/conflict_review_screen.dart';
import 'package:olf_app/src/health/health_import.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';
import 'conflict_fixtures.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToApps(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Connect a health app'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('connected, never synced: the tile explains what is shared', (
    tester,
  ) async {
    final db = memoryDb();
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.appleHealthConnected, 'true');

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
        await scrollToApps(tester);
        expect(
          find.textContaining(
            'Sharing menstrual flow and basal body '
            'temperature',
          ),
          findsOneWidget,
        );
        expect(find.text('Sync now'), findsOneWidget);
      },
    );
  });

  testWidgets('a completed sync shows counts and how long ago it ran', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await settings.set(SettingKeys.appleHealthConnected, 'true');
    await settings.set(
      SettingKeys.appleHealthLastSync,
      HealthSyncSummary(
        added: 3,
        updated: 2,
        needsReview: 1,
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      ).encode(),
    );

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
        await scrollToApps(tester);
        expect(
          find.textContaining('Last sync: added 3, updated 2 · 5 min ago'),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('the review row appears with the conflict count and opens the '
      'review screen', (tester) async {
    final db = memoryDb();
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.appleHealthConnected, 'true');

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
            flowConflict(
              DateTime(2026, 5, 11),
              local: FlowIntensity.light,
              incoming: FlowIntensity.heavy,
            ),
          ]),
        ),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToApps(tester);

        final row = find.text('2 differences to review');
        expect(row, findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(AppBar, ConflictReviewScreen.title),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('reduce spoken detail redacts the review-row subtitle', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await settings.set(SettingKeys.reduceSpokenDetail, 'true');
    await settings.set(SettingKeys.appleHealthConnected, 'true');

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
        await openSettings(tester);
        await scrollToApps(tester);

        final subtitle = find.textContaining('disagree on some days');
        expect(subtitle, findsOneWidget);
        expect(
          tester.widget<Text>(subtitle).semanticsLabel,
          'Some entries need your review.',
        );
      },
    );
  });

  testWidgets(
    'the passive Apple Watch wrist-temperature line appears once readings '
    'exist, and its subtitle is redacted (p8.1a)',
    (tester) async {
      final db = memoryDb();
      final settings = DriftSettingsRepository(db);
      await settings.set(SettingKeys.reduceSpokenDetail, 'true');
      await settings.set(SettingKeys.appleHealthConnected, 'true');
      final bbt = DriftBbtRepository(db);
      for (final ago in const [1, 2]) {
        await bbt.setTemp(
          DateTime.now().subtract(Duration(days: ago)),
          36.8,
          source: HealthDataSource.appleHealth,
          externalId: 'hk-wrist-$ago',
          measurementKind: BbtMeasurementKind.sleepingWrist,
        );
      }

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
          await scrollToApps(tester);

          expect(find.text('Apple Watch wrist temperature'), findsOneWidget);
          final subtitle = find.textContaining('2 passive readings');
          expect(subtitle, findsOneWidget);
          expect(
            tester.widget<Text>(subtitle).semanticsLabel,
            'Passive Apple Watch readings are being imported.',
          );
        },
      );
    },
  );

  testWidgets(
    'no passive wrist line when there are no wrist readings (p8.1a)',
    (tester) async {
      final db = memoryDb();
      await DriftSettingsRepository(
        db,
      ).set(SettingKeys.appleHealthConnected, 'true');

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
          await scrollToApps(tester);
          expect(find.text('Apple Watch wrist temperature'), findsNothing);
        },
      );
    },
  );

  testWidgets('the counts update after a manual sync', (tester) async {
    final db = memoryDb();
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.appleHealthConnected, 'true');
    final day = DateTime.now().subtract(const Duration(days: 3));
    final gateway = FakeHealthPlatformGateway(
      seedSamples: [
        HealthSample.point(
          type: HealthSampleType.basalBodyTemperature,
          at: DateTime(day.year, day.month, day.day),
          value: 36.7,
          unit: HealthUnit.celsius,
          source: HealthDataSource.appleHealth,
          externalId: 'new-1',
        ),
      ],
    );

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(gateway),
      ],
      body: () async {
        await openSettings(tester);
        await scrollToApps(tester);
        await tester.tap(find.text('Sync now'));
        await flush(tester, 40);

        expect(
          find.textContaining('Last sync: added 1, updated 0'),
          findsOneWidget,
        );
      },
    );
  });
}
