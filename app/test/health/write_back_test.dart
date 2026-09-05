import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_write_back.dart';
import 'package:olf_core/olf_core.dart';

/// p6.4 write-back: a single in-app flow / BBT log, edit or clear is pushed out
/// to the connected platform, best-effort. [HealthWriteBack] is a plain class
/// over the [HealthPlatformGateway] seam, so these tests drive it directly
/// against a [FakeHealthPlatformGateway] — no Riverpod, no widget tree.
void main() {
  final day = DateTime(2026, 5, 10);

  group('connected', () {
    late FakeHealthPlatformGateway gateway;
    late HealthWriteBack writeBack;

    setUp(() {
      gateway = FakeHealthPlatformGateway();
      writeBack = HealthWriteBack(gateway: gateway, connected: true);
    });

    test('logging flow writes one menstrual-flow sample at that day', () async {
      await writeBack.flowLogged(day, intensity: FlowIntensity.medium);

      expect(gateway.writes, hasLength(1));
      final s = gateway.writes.single;
      expect(s.type, HealthSampleType.menstrualFlow);
      expect(s.value, FlowIntensity.medium.index.toDouble());
      expect(s.unit, HealthUnit.flowLevel);
      expect(s.source, HealthDataSource.manual);
      expect(s.startAt, dateOnly(day));
    });

    test('logging BBT writes one basal-body-temperature sample', () async {
      await writeBack.bbtLogged(day, celsius: 36.62);

      final s = gateway.writes.single;
      expect(s.type, HealthSampleType.basalBodyTemperature);
      expect(s.value, 36.62);
      expect(s.unit, HealthUnit.celsius);
      expect(s.source, HealthDataSource.manual);
    });

    test('editing an already-imported row still writes back (source is '
        'manual by the time it reaches write-back)', () async {
      // p6.2 flips source → manual on edit before the repo persists; write-back
      // only ever sees the post-edit value.
      await writeBack.bbtLogged(day, celsius: 37.0);

      expect(gateway.writes.single.value, 37.0);
      expect(gateway.writes.single.source, HealthDataSource.manual);
    });

    test('clearing flow deletes that day/type from the platform', () async {
      gateway.seed(
        HealthSample.point(
          type: HealthSampleType.menstrualFlow,
          at: dateOnly(day),
          value: FlowIntensity.light.index.toDouble(),
          unit: HealthUnit.flowLevel,
          source: HealthDataSource.manual,
          externalId: 'f1',
        ),
      );

      await writeBack.flowCleared(day);

      expect(gateway.samples, isEmpty);
    });

    test('clearing BBT leaves an unrelated day untouched', () async {
      gateway
        ..seed(
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: dateOnly(day),
            value: 36.5,
            unit: HealthUnit.celsius,
            source: HealthDataSource.manual,
          ),
        )
        ..seed(
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: dateOnly(day).add(const Duration(days: 1)),
            value: 36.7,
            unit: HealthUnit.celsius,
            source: HealthDataSource.manual,
          ),
        );

      await writeBack.bbtCleared(day);

      expect(gateway.samples, hasLength(1));
      expect(gateway.samples.single.value, 36.7);
    });

    test(
      'a gateway failure is swallowed — write-back is best-effort',
      () async {
        final downGateway = FakeHealthPlatformGateway(available: false);
        final wb = HealthWriteBack(gateway: downGateway, connected: true);

        // Must not throw even though the platform is unreachable.
        await wb.flowLogged(day, intensity: FlowIntensity.heavy);
        await wb.bbtCleared(day);
      },
    );
  });

  group('not connected', () {
    test('disabled write-back never touches the gateway', () async {
      const writeBack = HealthWriteBack.disabled();
      // No throw, nothing to observe — the point is it is a safe no-op.
      await writeBack.flowLogged(day, intensity: FlowIntensity.medium);
      await writeBack.bbtLogged(day, celsius: 36.6);
      await writeBack.flowCleared(day);
      await writeBack.bbtCleared(day);
    });

    test('connected:false with a live gateway still does not write', () async {
      final gateway = FakeHealthPlatformGateway();
      final writeBack = HealthWriteBack(gateway: gateway, connected: false);

      await writeBack.flowLogged(day, intensity: FlowIntensity.medium);

      expect(gateway.writes, isEmpty);
      expect(gateway.samples, isEmpty);
    });
  });

  group('round trip (no duplicate)', () {
    test('a written-back manual row read back reconciles as a skip', () async {
      final gateway = FakeHealthPlatformGateway();
      final writeBack = HealthWriteBack(gateway: gateway, connected: true);

      await writeBack.bbtLogged(day, celsius: 36.6);

      // The platform now echoes it back on the next read, platform-sourced.
      final incoming = await gateway.read(
        types: {HealthSampleType.basalBodyTemperature},
        from: day.subtract(const Duration(days: 1)),
        to: day.add(const Duration(days: 1)),
      );
      expect(incoming, hasLength(1));

      final plan = const ImportReconciler().reconcile(
        local: [
          LocalSampleView(
            localId: '2026-05-10',
            type: HealthSampleType.basalBodyTemperature,
            day: dateOnly(day),
            value: 36.6,
            unit: HealthUnit.celsius,
            source: HealthDataSource.manual,
          ),
        ],
        incoming: [
          // read() returns the sample olf wrote; treat it as platform-sourced
          // on the way back in, exactly as MethodChannelHealthGateway.read does.
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: dateOnly(day),
            value: incoming.single.value,
            unit: HealthUnit.celsius,
            source: HealthDataSource.appleHealth,
          ),
        ],
      );

      expect(plan.conflicts, isEmpty);
      expect(plan.inserts, isEmpty);
      expect(plan.updates, isEmpty);
      expect(plan.skipped, hasLength(1));
    });
  });
}
