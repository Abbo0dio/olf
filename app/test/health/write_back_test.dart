import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_import.dart';
import 'package:olf_app/src/health/health_write_back.dart';
import 'package:olf_core/olf_core.dart';

// The `writeBackFlow` / `writeBackBbt` provider helpers (the connected-gate +
// retention-cutoff lookup around this service) are covered end-to-end by
// `conflict_review_test.dart`'s "keep mine" path, which drives them through the
// full app container.

void main() {
  final clock = DateTime(2026, 6, 1, 8);
  final day = DateTime(2026, 5, 20);

  late AppDatabase db;
  late DriftBbtRepository bbt;
  late DriftDailyFlowRepository flow;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    bbt = DriftBbtRepository(db, now: () => clock);
    flow = DriftDailyFlowRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  HealthWriteBack writeBackWith(FakeHealthPlatformGateway gateway) =>
      HealthWriteBack(gateway: gateway, bbt: bbt, flow: flow);

  HealthImportService importWith(FakeHealthPlatformGateway gateway) =>
      HealthImportService(
        gateway: gateway,
        bbt: bbt,
        flow: flow,
        now: () => clock,
      );

  group('HealthWriteBack', () {
    test('a freshly logged BBT reading is pushed to the platform', () async {
      await bbt.setTemp(day, 36.62); // in-app log — manual, no external id
      final gateway = FakeHealthPlatformGateway();

      await writeBackWith(gateway).bbt(day);

      expect(gateway.writes, hasLength(1));
      final s = gateway.writes.single;
      expect(s.type, HealthSampleType.basalBodyTemperature);
      expect(s.value, 36.62);
      expect(s.source, HealthDataSource.manual);
      expect(s.externalId, isNull);
    });

    test('a freshly logged flow day is pushed to the platform', () async {
      await flow.setFlow(day, intensity: FlowIntensity.medium);
      final gateway = FakeHealthPlatformGateway();

      await writeBackWith(gateway).flow(day);

      expect(gateway.writes, hasLength(1));
      final s = gateway.writes.single;
      expect(s.type, HealthSampleType.menstrualFlow);
      expect(s.value, FlowIntensity.medium.index.toDouble());
      expect(s.source, HealthDataSource.manual);
    });

    test(
      'editing an imported row flips it to manual and writes it back under the '
      'original external id — the platform record updates, no duplicate',
      () async {
        // Row already imported from the platform.
        await bbt.setTemp(
          day,
          36.40,
          source: HealthDataSource.appleHealth,
          externalId: 'HK-1',
        );
        final gateway = FakeHealthPlatformGateway(
          seedSamples: [
            HealthSample.point(
              type: HealthSampleType.basalBodyTemperature,
              at: day,
              value: 36.40,
              unit: HealthUnit.celsius,
              source: HealthDataSource.appleHealth,
              externalId: 'HK-1',
            ),
          ],
        );

        // User edits it in the app (plain setTemp — no provenance args).
        await bbt.setTemp(day, 36.75);
        final row = (await bbt.tempOn(day))!;
        expect(row.source, 'manual'); // flipped
        expect(row.externalId, 'HK-1'); // link kept

        await writeBackWith(gateway).bbt(day);

        // The write carried the original id → the fake upserts in place.
        expect(gateway.writes.single.externalId, 'HK-1');
        expect(gateway.samples, hasLength(1));
        expect(gateway.samples.single.value, 36.75);

        // A follow-up sync sees no change: no dupe, no conflict.
        final result = await importWith(gateway).sync();
        expect(
          result.summary,
          HealthSyncSummary(added: 0, updated: 0, needsReview: 0, at: clock),
        );
        expect(result.conflicts, isEmpty);
        expect(await bbt.allEntries(), hasLength(1));
      },
    );

    test(
      'round-trips a fresh manual log with no duplicate on the next read',
      () async {
        await flow.setFlow(day, intensity: FlowIntensity.heavy);
        final gateway = FakeHealthPlatformGateway();

        await writeBackWith(gateway).flow(day);
        final result = await importWith(gateway).sync();

        expect(
          result.summary,
          HealthSyncSummary(added: 0, updated: 0, needsReview: 0, at: clock),
        );
        expect(result.conflicts, isEmpty);
        expect(await flow.allFlows(), hasLength(1));
      },
    );

    test('does not write back a day older than the retention cutoff', () async {
      final oldDay = DateTime(2026, 1, 10);
      await bbt.setTemp(oldDay, 36.5);
      final gateway = FakeHealthPlatformGateway();

      await writeBackWith(
        gateway,
      ).bbt(oldDay, retentionCutoff: DateTime(2026, 5, 1));

      expect(gateway.writes, isEmpty);
    });

    test('a write failure is swallowed, never rethrown', () async {
      await bbt.setTemp(day, 36.5);
      final gateway = FakeHealthPlatformGateway(available: false);

      // Must not throw.
      await writeBackWith(gateway).bbt(day);
    });
  });
}
