import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_import.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  final clock = DateTime(2026, 6, 1, 8);
  final day = DateTime(2026, 5, 10);

  late AppDatabase db;
  late DriftBbtRepository bbt;
  late DriftDailyFlowRepository flow;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    bbt = DriftBbtRepository(db, now: () => clock);
    flow = DriftDailyFlowRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  HealthImportService serviceWith(FakeHealthPlatformGateway gateway) =>
      HealthImportService(
        gateway: gateway,
        bbt: bbt,
        flow: flow,
        now: () => clock,
      );

  Future<HealthSyncSummary> syncSummary(
    FakeHealthPlatformGateway gateway, {
    DateTime? retentionCutoff,
  }) async => (await serviceWith(
    gateway,
  ).sync(retentionCutoff: retentionCutoff)).summary;

  HealthSample flowSample({
    required int flowOrdinal,
    String? externalId,
    HealthDataSource source = HealthDataSource.appleHealth,
  }) => HealthSample.point(
    type: HealthSampleType.menstrualFlow,
    at: day,
    value: flowOrdinal.toDouble(),
    unit: HealthUnit.flowLevel,
    source: source,
    externalId: externalId,
  );

  HealthSample bbtSample({
    required double celsius,
    String? externalId,
    HealthDataSource source = HealthDataSource.appleHealth,
  }) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: day,
    value: celsius,
    unit: HealthUnit.celsius,
    source: source,
    externalId: externalId,
  );

  test('inserts unmatched incoming samples into the local tables', () async {
    final gateway = FakeHealthPlatformGateway(
      seedSamples: [
        flowSample(flowOrdinal: FlowIntensity.medium.index, externalId: 'f1'),
        bbtSample(celsius: 36.6, externalId: 't1'),
      ],
    );

    final summary = await syncSummary(gateway);

    expect(
      summary,
      HealthSyncSummary(added: 2, updated: 0, needsReview: 0, at: clock),
    );

    final flowRow = (await flow.flowOn(day))!;
    expect(flowRow.intensity, FlowIntensity.medium);
    expect(flowRow.source, 'appleHealth');
    expect(flowRow.externalId, 'f1');

    final bbtRow = (await bbt.tempOn(day))!;
    expect(bbtRow.tempCelsius, 36.6);
    expect(bbtRow.source, 'appleHealth');
    expect(bbtRow.externalId, 't1');
  });

  test('updates a prior same-source row in place', () async {
    await bbt.setTemp(
      day,
      36.4,
      source: HealthDataSource.appleHealth,
      externalId: 't1',
    );

    final gateway = FakeHealthPlatformGateway(
      seedSamples: [bbtSample(celsius: 36.9, externalId: 't1')],
    );

    final summary = await syncSummary(gateway);

    expect(summary.updated, 1);
    expect(summary.added, 0);
    expect((await bbt.tempOn(day))!.tempCelsius, 36.9);
  });

  test('never overwrites a manual row — it is counted for review', () async {
    await bbt.setTemp(day, 36.4); // manual

    final gateway = FakeHealthPlatformGateway(
      seedSamples: [bbtSample(celsius: 36.9, externalId: 't9')],
    );

    final summary = await syncSummary(gateway);

    expect(summary.needsReview, 1);
    expect(summary.added, 0);
    expect(summary.updated, 0);
    final row = (await bbt.tempOn(day))!;
    expect(row.tempCelsius, 36.4); // untouched
    expect(row.source, 'manual');
  });

  test(
    'pushes the user\'s manual rows the platform is missing back out',
    () async {
      await bbt.setTemp(day, 36.5); // manual, not in HealthKit
      await flow.setFlow(day, intensity: FlowIntensity.light); // manual

      final gateway = FakeHealthPlatformGateway();
      await syncSummary(gateway);

      expect(gateway.writes, hasLength(2));
      expect(gateway.writes.map((s) => s.type).toSet(), {
        HealthSampleType.menstrualFlow,
        HealthSampleType.basalBodyTemperature,
      });
      expect(
        gateway.writes.every((s) => s.source == HealthDataSource.manual),
        isTrue,
      );
    },
  );

  test('does not push a manual row the platform already has', () async {
    await bbt.setTemp(day, 36.5); // manual

    final gateway = FakeHealthPlatformGateway(
      seedSamples: [bbtSample(celsius: 36.5, externalId: 't1')],
    );
    await syncSummary(gateway);

    expect(gateway.writes, isEmpty);
  });

  test(
    'does not re-import or push data older than the retention window',
    () async {
      // A local manual row and a platform sample, both well before the cutoff.
      final oldDay = DateTime(2026, 1, 1);
      await bbt.setTemp(oldDay, 36.5); // manual, out of window
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: oldDay,
            value: 36.9,
            unit: HealthUnit.celsius,
            source: HealthDataSource.appleHealth,
            externalId: 'old-1',
          ),
        ],
      );

      // Keep only the last ~30 days (clock is 2026-06-01).
      final summary = await syncSummary(
        gateway,
        retentionCutoff: DateTime(2026, 5, 1),
      );

      // Nothing imported, nothing flagged, nothing written back for the old day.
      expect(
        summary,
        HealthSyncSummary(added: 0, updated: 0, needsReview: 0, at: clock),
      );
      expect((await bbt.tempOn(oldDay))!.tempCelsius, 36.5); // untouched
      expect(gateway.writes, isEmpty);
    },
  );

  group('connect', () {
    test(
      'throws HealthAuthorizationDenied when the sheet is refused',
      () async {
        final gateway = FakeHealthPlatformGateway(
          authOutcome: HealthAuthStatus.denied,
        );
        await expectLater(
          serviceWith(gateway).connect(),
          throwsA(isA<HealthAuthorizationDenied>()),
        );
      },
    );

    test('runs a full sync once authorized', () async {
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [bbtSample(celsius: 36.7, externalId: 't1')],
      );
      final result = await serviceWith(gateway).connect();
      expect(result.summary.added, 1);
      expect(gateway.authRequests, hasLength(1));
      expect(gateway.authRequests.single.access, HealthAccess.readWrite);
    });
  });

  test('an unavailable platform surfaces HealthPlatformUnavailable', () async {
    final gateway = FakeHealthPlatformGateway(available: false);
    await expectLater(
      serviceWith(gateway).sync(),
      throwsA(isA<HealthPlatformUnavailable>()),
    );
  });

  group('HealthSyncSummary encoding', () {
    test('round-trips through encode/decode, timestamp included', () {
      final s = HealthSyncSummary(
        added: 3,
        updated: 1,
        needsReview: 2,
        at: DateTime(2026, 6, 1, 8, 30),
      );
      expect(HealthSyncSummary.decode(s.encode()), s);
    });

    test('round-trips with no timestamp', () {
      const s = HealthSyncSummary(added: 3, updated: 1, needsReview: 2);
      expect(s.encode(), '3,1,2,');
      expect(HealthSyncSummary.decode(s.encode()), s);
    });

    test('still accepts the pre-p6.4 3-field form', () {
      final decoded = HealthSyncSummary.decode('2,1,0');
      expect(
        decoded,
        const HealthSyncSummary(added: 2, updated: 1, needsReview: 0),
      );
      expect(decoded!.at, isNull);
    });

    test('decode rejects malformed input', () {
      expect(HealthSyncSummary.decode(null), isNull);
      expect(HealthSyncSummary.decode('1,2'), isNull);
      expect(HealthSyncSummary.decode('a,b,c'), isNull);
      expect(HealthSyncSummary.decode('1,2,3,not-a-date'), isNull);
    });
  });
}
