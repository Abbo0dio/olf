import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/bbt/bbt_providers.dart';
import 'package:olf_app/src/flow/flow_providers.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p6.4 conflict-review resolutions. The in-memory [healthConflictsProvider]
/// holds the conflicts from the last sync; each of the three actions must move
/// to a deterministic stored outcome and drop the row from the list.
void main() {
  final day = DateTime(2026, 5, 10);

  ReconciliationConflict bbtConflict({
    double local = 36.5,
    double incoming = 36.9,
  }) => ReconciliationConflict(
    localId: '2026-05-10',
    local: LocalSampleView(
      localId: '2026-05-10',
      type: HealthSampleType.basalBodyTemperature,
      day: dateOnly(day),
      value: local,
      unit: HealthUnit.celsius,
      source: HealthDataSource.manual,
    ),
    incoming: HealthSample.point(
      type: HealthSampleType.basalBodyTemperature,
      at: dateOnly(day),
      value: incoming,
      unit: HealthUnit.celsius,
      source: HealthDataSource.appleHealth,
    ),
    reason: ConflictReason.manualDisagreement,
  );

  ReconciliationConflict flowConflict() => ReconciliationConflict(
    localId: '2026-05-10',
    local: LocalSampleView(
      localId: '2026-05-10',
      type: HealthSampleType.menstrualFlow,
      day: dateOnly(day),
      value: FlowIntensity.light.index.toDouble(),
      unit: HealthUnit.flowLevel,
      source: HealthDataSource.manual,
    ),
    incoming: HealthSample.point(
      type: HealthSampleType.menstrualFlow,
      at: dateOnly(day),
      value: FlowIntensity.heavy.index.toDouble(),
      unit: HealthUnit.flowLevel,
      source: HealthDataSource.appleHealth,
    ),
    reason: ConflictReason.manualDisagreement,
  );

  /// Pumps a headless host that exposes a [WidgetRef] and has the drift
  /// database resolved, so the resolution helpers can be called directly.
  Future<WidgetRef> host(
    WidgetTester tester, {
    required AppDatabase db,
    required FakeHealthPlatformGateway gateway,
    required List<ReconciliationConflict> conflicts,
  }) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbOverride(db),
          healthPlatformGatewayProvider.overrideWithValue(gateway),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(appDatabaseProvider); // force the FutureProvider to load
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    captured.read(healthConflictsProvider.notifier).state = conflicts;
    // Unmount and flush drift's stream-close timer before the binding's
    // end-of-test invariant check.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
    return captured;
  }

  testWidgets('keep mine — pushes the local value to the platform and drops '
      'the row', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeHealthPlatformGateway();
    final conflict = bbtConflict(local: 36.5, incoming: 36.9);
    final ref = await host(
      tester,
      db: db,
      gateway: gateway,
      conflicts: [conflict],
    );

    await resolveConflictKeepLocal(ref, conflict);

    expect(gateway.writes, hasLength(1));
    expect(gateway.writes.single.value, 36.5);
    expect(gateway.writes.single.source, HealthDataSource.manual);
    expect(ref.read(healthConflictsProvider), isEmpty);
  });

  testWidgets('use theirs (BBT) — writes the incoming value as a manual local '
      'entry and drops the row', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeHealthPlatformGateway();
    final conflict = bbtConflict(local: 36.5, incoming: 36.9);
    final ref = await host(
      tester,
      db: db,
      gateway: gateway,
      conflicts: [conflict],
    );

    await resolveConflictTakeIncoming(ref, conflict);

    final row = await ref.read(bbtRepositoryProvider).tempOn(dateOnly(day));
    expect(row, isNotNull);
    expect(row!.tempCelsius, 36.9);
    expect(row.source, 'manual');
    expect(gateway.writes, isEmpty);
    expect(ref.read(healthConflictsProvider), isEmpty);
  });

  testWidgets('use theirs (flow) — writes the incoming intensity locally', (
    tester,
  ) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeHealthPlatformGateway();
    final conflict = flowConflict();
    final ref = await host(
      tester,
      db: db,
      gateway: gateway,
      conflicts: [conflict],
    );

    await resolveConflictTakeIncoming(ref, conflict);

    final row = await ref
        .read(dailyFlowRepositoryProvider)
        .flowOn(dateOnly(day));
    expect(row, isNotNull);
    expect(row!.intensity, FlowIntensity.heavy);
    expect(ref.read(healthConflictsProvider), isEmpty);
  });

  testWidgets('later — drops the row and changes nothing', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeHealthPlatformGateway();
    final conflict = bbtConflict();
    final ref = await host(
      tester,
      db: db,
      gateway: gateway,
      conflicts: [conflict],
    );

    dismissConflict(ref, conflict);

    expect(gateway.writes, isEmpty);
    expect(await ref.read(bbtRepositoryProvider).tempOn(dateOnly(day)), isNull);
    expect(ref.read(healthConflictsProvider), isEmpty);
  });

  testWidgets('resolving one of several leaves the rest', (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final gateway = FakeHealthPlatformGateway();
    final a = bbtConflict();
    final b = flowConflict();
    final ref = await host(tester, db: db, gateway: gateway, conflicts: [a, b]);

    dismissConflict(ref, a);

    expect(ref.read(healthConflictsProvider), [b]);
  });
}
