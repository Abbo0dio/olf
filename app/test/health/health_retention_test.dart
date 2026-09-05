import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_import.dart';
import 'package:olf_core/olf_core.dart';

/// p6.4 × p2.3: a sync must run the retention purge first, must not re-import
/// samples older than the retention window, and must not write back rows the
/// purge has just dropped.
void main() {
  final clock = DateTime(2026, 6, 1, 8);
  final cutoff = DateTime(2026, 5, 1);
  final oldDay = DateTime(2026, 3, 10); // before the window
  final recentDay = DateTime(2026, 5, 20); // inside the window

  late AppDatabase db;
  late DriftBbtRepository bbt;
  late DriftDailyFlowRepository flow;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    bbt = DriftBbtRepository(db, now: () => clock);
    flow = DriftDailyFlowRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  HealthImportService service(
    FakeHealthPlatformGateway gateway, {
    Future<void> Function()? purgeBeforeSync,
  }) => HealthImportService(
    gateway: gateway,
    bbt: bbt,
    flow: flow,
    now: () => clock,
    purgeBeforeSync: purgeBeforeSync,
    retentionCutoff: () => cutoff,
  );

  HealthSample bbtSample(DateTime at, double celsius, String id) =>
      HealthSample.point(
        type: HealthSampleType.basalBodyTemperature,
        at: at,
        value: celsius,
        unit: HealthUnit.celsius,
        source: HealthDataSource.appleHealth,
        externalId: id,
      );

  test('an incoming sample older than the cutoff is not imported', () async {
    final gateway = FakeHealthPlatformGateway(
      seedSamples: [
        bbtSample(oldDay, 36.3, 'old'),
        bbtSample(recentDay, 36.8, 'recent'),
      ],
    );

    final result = await service(gateway).sync();

    expect(result.summary.added, 1);
    expect(await bbt.tempOn(recentDay), isNotNull);
    expect(await bbt.tempOn(oldDay), isNull);
  });

  test('purgeBeforeSync runs before the reconcile, so a row it drops is '
      'neither kept nor written back', () async {
    // A stale manual row the retention sweep is about to remove.
    await bbt.setTemp(oldDay, 36.4);

    final gateway = FakeHealthPlatformGateway();
    var purged = false;
    await service(
      gateway,
      purgeBeforeSync: () async {
        purged = true;
        await bbt.clearTemp(oldDay);
      },
    ).sync();

    expect(purged, isTrue);
    expect(await bbt.tempOn(oldDay), isNull);
    // The purged row must not have been pushed out to the platform.
    expect(gateway.writes, isEmpty);
  });

  test('a manual row inside the window is still written back', () async {
    await bbt.setTemp(recentDay, 36.6); // manual, platform is missing it

    final gateway = FakeHealthPlatformGateway();
    await service(gateway).sync();

    expect(gateway.writes, hasLength(1));
    expect(gateway.writes.single.day, dateOnly(recentDay));
  });

  test(
    'with no retention window everything in the read range imports',
    () async {
      final gateway = FakeHealthPlatformGateway(
        seedSamples: [bbtSample(recentDay, 36.9, 'r')],
      );
      final noRetention = HealthImportService(
        gateway: gateway,
        bbt: bbt,
        flow: flow,
        now: () => clock,
      );

      final result = await noRetention.sync();

      expect(result.summary.added, 1);
    },
  );
}
