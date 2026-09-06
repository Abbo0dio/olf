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
    String? device,
  }) => HealthSample.point(
    type: HealthSampleType.menstrualFlow,
    at: day,
    value: flowOrdinal.toDouble(),
    unit: HealthUnit.flowLevel,
    source: source,
    externalId: externalId,
    sourceDevice: device,
  );

  HealthSample bbtSample({
    required double celsius,
    String? externalId,
    HealthDataSource source = HealthDataSource.appleHealth,
    String? device,
  }) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: day,
    value: celsius,
    unit: HealthUnit.celsius,
    source: source,
    externalId: externalId,
    sourceDevice: device,
  );

  HealthSample wristSample({
    required double celsius,
    String? externalId,
    DateTime? at,
  }) => HealthSample.point(
    type: HealthSampleType.wristTemperature,
    at: at ?? day,
    value: celsius,
    unit: HealthUnit.celsius,
    source: HealthDataSource.appleHealth,
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

  group('passive wrist temperature (p8.1a)', () {
    test(
      'an unmatched wrist reading is inserted tagged sleepingWrist',
      () async {
        final gateway = FakeHealthPlatformGateway(
          seedSamples: [wristSample(celsius: 36.9, externalId: 'w1')],
        );

        final summary = await syncSummary(gateway);
        expect(summary.added, 1);
        expect(summary.needsReview, 0);

        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 36.9);
        expect(row.measurementKind, BbtMeasurementKind.sleepingWrist);
        expect(row.source, 'appleHealth');
        expect(row.externalId, 'w1');
      },
    );

    test(
      'a revised wrist reading updates the prior wrist row in place',
      () async {
        await bbt.setTemp(
          day,
          36.7,
          source: HealthDataSource.appleHealth,
          externalId: 'w1',
          measurementKind: BbtMeasurementKind.sleepingWrist,
        );

        final gateway = FakeHealthPlatformGateway(
          seedSamples: [wristSample(celsius: 37.0, externalId: 'w1')],
        );
        final summary = await syncSummary(gateway);

        expect(summary.updated, 1);
        expect(summary.added, 0);
        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 37.0);
        expect(row.measurementKind, BbtMeasurementKind.sleepingWrist);
      },
    );

    test(
      'a wrist reading never overwrites a manual BBT — it is a conflict',
      () async {
        await bbt.setTemp(day, 36.4); // manual basal

        final gateway = FakeHealthPlatformGateway(
          seedSamples: [wristSample(celsius: 37.1, externalId: 'w9')],
        );
        final result = await serviceWith(gateway).sync();

        expect(result.summary.needsReview, 1);
        expect(result.summary.added, 0);
        expect(result.summary.updated, 0);
        expect(result.conflicts, hasLength(1));

        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 36.4); // untouched
        expect(row.source, 'manual');
        expect(row.measurementKind, BbtMeasurementKind.basal);
      },
    );

    test('a wrist reading wins the day slot over an existing appleHealth basal '
        'row, stored tagged sleepingWrist', () async {
      await bbt.setTemp(
        day,
        36.5,
        source: HealthDataSource.appleHealth,
        externalId: 'basal-1',
        measurementKind: BbtMeasurementKind.basal,
      );

      final gateway = FakeHealthPlatformGateway(
        seedSamples: [wristSample(celsius: 36.95, externalId: 'wrist-1')],
      );
      final summary = await syncSummary(gateway);

      expect(summary.updated, 1);
      final row = (await bbt.tempOn(day))!;
      expect(row.tempCelsius, 36.95);
      expect(row.measurementKind, BbtMeasurementKind.sleepingWrist);
    });

    test('a wrist reading is never written back out', () async {
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [wristSample(celsius: 36.9, externalId: 'w1')],
      );
      await syncSummary(gateway);
      expect(gateway.writes, isEmpty);
    });

    test(
      'a wrist import leaves a manual basal day on another date untouched',
      () async {
        final otherDay = DateTime(2026, 5, 12);
        await bbt.setTemp(otherDay, 36.42); // manual basal, unrelated day

        final gateway = FakeHealthPlatformGateway(
          seedSamples: [wristSample(celsius: 37.0, externalId: 'w1')],
        );
        await syncSummary(gateway);

        final untouched = (await bbt.tempOn(otherDay))!;
        expect(untouched.tempCelsius, 36.42);
        expect(untouched.measurementKind, BbtMeasurementKind.basal);
        expect(untouched.source, 'manual');
      },
    );
  });

  group('device provenance (p8.2)', () {
    test('an imported reading stores its originating-device tag', () async {
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [
          bbtSample(celsius: 36.6, externalId: 't1', device: 'Oura'),
          flowSample(
            flowOrdinal: FlowIntensity.light.index,
            externalId: 'f1',
            device: 'com.ouraring.oura',
          ),
        ],
      );

      await syncSummary(gateway);

      expect((await bbt.tempOn(day))!.sourceDevice, 'Oura');
      expect((await flow.flowOn(day))!.sourceDevice, 'com.ouraring.oura');
    });

    test('an update from the same device refreshes the tag', () async {
      await bbt.setTemp(
        day,
        36.4,
        source: HealthDataSource.appleHealth,
        externalId: 't1',
        sourceDevice: 'Oura',
      );
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [
          bbtSample(celsius: 36.9, externalId: 't1', device: 'Oura'),
        ],
      );

      final summary = await syncSummary(gateway);
      expect(summary.updated, 1);
      final row = (await bbt.tempOn(day))!;
      expect(row.tempCelsius, 36.9);
      expect(row.sourceDevice, 'Oura');
    });

    test('editing an imported tagged reading in-app clears the tag', () async {
      await bbt.setTemp(
        day,
        36.6,
        source: HealthDataSource.appleHealth,
        externalId: 't1',
        sourceDevice: 'Oura',
      );
      // A plain in-app correction: no source, no device passed.
      await bbt.setTemp(day, 36.55);

      final row = (await bbt.tempOn(day))!;
      expect(row.source, 'manual');
      expect(row.sourceDevice, isNull);
      expect(row.externalId, 't1'); // externalId stays sticky
    });

    test(
      'two devices disagree on the same day → one review, no clobber',
      () async {
        // A stored Oura reading, then a Garmin sync for the same day with a
        // materially different value.
        await bbt.setTemp(
          day,
          36.4,
          source: HealthDataSource.appleHealth,
          externalId: 'oura-1',
          sourceDevice: 'Oura',
        );
        final gateway = FakeHealthPlatformGateway(
          seedSamples: [
            bbtSample(celsius: 36.95, externalId: 'garmin-1', device: 'Garmin'),
          ],
        );

        final result = await serviceWith(gateway).sync();

        expect(result.summary.needsReview, 1);
        expect(result.summary.updated, 0);
        expect(result.summary.added, 0);
        expect(
          result.conflicts.single.reason,
          ConflictReason.crossDeviceDisagreement,
        );
        // The stored Oura reading is untouched — olf picked no winner.
        final row = (await bbt.tempOn(day))!;
        expect(row.tempCelsius, 36.4);
        expect(row.sourceDevice, 'Oura');
      },
    );

    test(
      'two devices that agree on the same day → one reading, no review',
      () async {
        await bbt.setTemp(
          day,
          36.50,
          source: HealthDataSource.appleHealth,
          externalId: 'oura-1',
          sourceDevice: 'Oura',
        );
        final gateway = FakeHealthPlatformGateway(
          seedSamples: [
            bbtSample(
              celsius: 36.504,
              externalId: 'garmin-1',
              device: 'Garmin',
            ),
          ],
        );

        final summary = await syncSummary(gateway);
        expect(summary.needsReview, 0);
        expect(summary.updated, 0);
        expect(summary.added, 0);
        expect((await bbt.tempOn(day))!.sourceDevice, 'Oura'); // unchanged
      },
    );
  });

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
