import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/conflict_review_screen.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';
import 'conflict_fixtures.dart';

void main() {
  final day = DateTime(2026, 5, 10);
  final flowDay = DateTime(2026, 5, 11);

  Future<void> openReview(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
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
  }

  /// A connected app with [conflicts] pending and [seed] already in the fake
  /// platform store.
  List<Override> overridesFor({
    required AppDatabase db,
    required List<ReconciliationConflict> conflicts,
    List<HealthSample> seed = const [],
  }) => [
    dbOverride(db),
    healthPlatformGatewayProvider.overrideWithValue(
      FakeHealthPlatformGateway(seedSamples: seed),
    ),
    healthConnectedProvider.overrideWith((ref) => Stream.value(true)),
    healthConflictsProvider.overrideWith(seededConflicts(conflicts)),
  ];

  testWidgets('keep mine: the local BBT value is written back, nothing changes '
      'locally, the conflict clears', (tester) async {
    final db = memoryDb();
    final bbt = DriftBbtRepository(db);
    await bbt.setTemp(
      day,
      36.4,
      source: HealthDataSource.appleHealth,
      externalId: 'HK-1',
    );
    // The user has since edited it to a manual value that disagrees.
    await bbt.setTemp(day, 36.4);

    final gateway = FakeHealthPlatformGateway(
      seedSamples: [
        HealthSample.point(
          type: HealthSampleType.basalBodyTemperature,
          at: day,
          value: 36.9,
          unit: HealthUnit.celsius,
          source: HealthDataSource.appleHealth,
          externalId: 'HK-1',
        ),
      ],
    );

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        healthPlatformGatewayProvider.overrideWithValue(gateway),
        healthConnectedProvider.overrideWith((ref) => Stream.value(true)),
        healthConflictsProvider.overrideWith(
          seededConflicts([
            bbtConflict(day, local: 36.4, incoming: 36.9, externalId: 'HK-1'),
          ]),
        ),
      ],
      body: () async {
        await openReview(tester);
        await tester.tap(find.text('Keep mine'));
        await flush(tester, 30);

        // Local row untouched.
        expect((await bbt.tempOn(day))!.tempCelsius, 36.4);
        // Pushed out under the same id → the fake now holds the local value.
        expect(gateway.samples.single.externalId, 'HK-1');
        expect(gateway.samples.single.value, 36.4);
        // Conflict gone → empty state.
        expect(find.text('Nothing to review.'), findsOneWidget);
      },
    );
  });

  testWidgets('use theirs (BBT): the incoming value is stored as a manual '
      'entry and the conflict clears', (tester) async {
    final db = memoryDb();
    final bbt = DriftBbtRepository(db);
    await bbt.setTemp(day, 36.4); // manual

    await pumpOlf(
      tester,
      overrides: overridesFor(
        db: db,
        conflicts: [bbtConflict(day, local: 36.4, incoming: 36.9)],
      ),
      body: () async {
        await openReview(tester);
        await tester.tap(find.text('Use Health Connect'));
        await flush(tester, 30);

        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 36.9);
        expect(row.source, 'manual');
        expect(find.text('Nothing to review.'), findsOneWidget);
      },
    );
  });

  testWidgets('use theirs (flow): the incoming intensity is stored as manual', (
    tester,
  ) async {
    final db = memoryDb();
    final flow = DriftDailyFlowRepository(db);
    await flow.setFlow(flowDay, intensity: FlowIntensity.light);

    await pumpOlf(
      tester,
      overrides: overridesFor(
        db: db,
        conflicts: [
          flowConflict(
            flowDay,
            local: FlowIntensity.light,
            incoming: FlowIntensity.heavy,
          ),
        ],
      ),
      body: () async {
        await openReview(tester);
        await tester.tap(find.text('Use Health Connect'));
        await flush(tester, 30);

        final row = (await flow.flowOn(flowDay))!;
        expect(row.intensity, FlowIntensity.heavy);
        expect(row.source, 'manual');
      },
    );
  });

  testWidgets(
    'dismiss: nothing is written on either side, the conflict clears',
    (tester) async {
      final db = memoryDb();
      final bbt = DriftBbtRepository(db);
      await bbt.setTemp(day, 36.4);
      final gateway = FakeHealthPlatformGateway();

      await pumpOlf(
        tester,
        overrides: [
          dbOverride(db),
          healthPlatformGatewayProvider.overrideWithValue(gateway),
          healthConnectedProvider.overrideWith((ref) => Stream.value(true)),
          healthConflictsProvider.overrideWith(
            seededConflicts([bbtConflict(day, local: 36.4, incoming: 36.9)]),
          ),
        ],
        body: () async {
          await openReview(tester);
          await tester.tap(find.text('Dismiss'));
          await flush(tester, 20);

          expect((await bbt.tempOn(day))!.tempCelsius, 36.4);
          expect(gateway.writes, isEmpty);
          expect(find.text('Nothing to review.'), findsOneWidget);
        },
      );
    },
  );

  testWidgets('resolving one of several leaves the rest', (tester) async {
    final db = memoryDb();
    await DriftBbtRepository(db).setTemp(day, 36.4);
    await DriftDailyFlowRepository(
      db,
    ).setFlow(flowDay, intensity: FlowIntensity.light);

    await pumpOlf(
      tester,
      overrides: overridesFor(
        db: db,
        conflicts: [
          bbtConflict(day, local: 36.4, incoming: 36.9),
          flowConflict(
            flowDay,
            local: FlowIntensity.light,
            incoming: FlowIntensity.heavy,
          ),
        ],
      ),
      body: () async {
        await openReview(tester);
        expect(find.text('Dismiss'), findsNWidgets(2));
        await tester.tap(find.text('Dismiss').first);
        await flush(tester, 20);
        expect(find.text('Dismiss'), findsOneWidget);
        expect(find.text('Nothing to review.'), findsNothing);
      },
    );
  });
}
