import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final from = DateTime(2026, 1, 1);
  final to = DateTime(2026, 12, 31);

  HealthSample flow(
    int day, {
    String? id,
    HealthDataSource src = HealthDataSource.appleHealth,
  }) => HealthSample.point(
    type: HealthSampleType.menstrualFlow,
    at: DateTime(2026, 6, day),
    value: 2,
    unit: HealthUnit.flowLevel,
    source: src,
    externalId: id,
  );

  group('FakeHealthPlatformGateway', () {
    test('honours the availability contract', () async {
      final g = FakeHealthPlatformGateway(available: false);
      expect(g.isAvailable, isFalse);
      expect(
        () => g.read(types: {HealthSampleType.sleep}, from: from, to: to),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
      expect(
        () => g.write([flow(1)]),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
      expect(
        () => g.requestAuthorization({
          HealthSampleType.sleep,
        }, access: HealthAccess.read),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
      expect(
        () => g.authorizationStatus({
          HealthSampleType.sleep,
        }, access: HealthAccess.read),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
      expect(
        () => g.delete(type: HealthSampleType.sleep, from: from, to: to),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
    });

    test('records auth requests and applies the scripted outcome', () async {
      final g = FakeHealthPlatformGateway(authOutcome: HealthAuthStatus.denied);
      final result = await g.requestAuthorization({
        HealthSampleType.menstrualFlow,
        HealthSampleType.sleep,
      }, access: HealthAccess.readWrite);
      expect(result, HealthAuthStatus.denied);
      expect(g.authRequests, hasLength(1));
      expect(g.authRequests.single.access, HealthAccess.readWrite);
      expect(g.authRequests.single.types, {
        HealthSampleType.menstrualFlow,
        HealthSampleType.sleep,
      });
      expect(
        await g.authorizationStatus({
          HealthSampleType.menstrualFlow,
        }, access: HealthAccess.readWrite),
        HealthAuthStatus.denied,
      );
    });

    test(
      'authorizationStatus reports the most cautious mixed answer',
      () async {
        final g = FakeHealthPlatformGateway(
          seedStatus: {
            HealthSampleType.menstrualFlow: HealthAuthStatus.granted,
            HealthSampleType.sleep: HealthAuthStatus.denied,
          },
        );
        expect(
          await g.authorizationStatus({
            HealthSampleType.menstrualFlow,
            HealthSampleType.sleep,
          }, access: HealthAccess.read),
          HealthAuthStatus.denied,
        );
        expect(
          await g.authorizationStatus({
            HealthSampleType.menstrualFlow,
            HealthSampleType.bodyTemperature,
          }, access: HealthAccess.read),
          HealthAuthStatus.notDetermined,
        );
      },
    );

    test('read filters by type and inclusive date range', () async {
      final g = FakeHealthPlatformGateway(
        seedSamples: [
          flow(1, id: 'a'),
          flow(15, id: 'b'),
          flow(20, id: 'c'),
        ],
      );
      g.seed(
        HealthSample.point(
          type: HealthSampleType.sleep,
          at: DateTime(2026, 6, 15),
          value: 400,
          unit: HealthUnit.minutes,
          source: HealthDataSource.appleHealth,
          externalId: 's',
        ),
      );

      final flows = await g.read(
        types: {HealthSampleType.menstrualFlow},
        from: DateTime(2026, 6, 10),
        to: DateTime(2026, 6, 20),
      );
      expect(flows.map((s) => s.externalId), ['b', 'c']);
    });

    test('write upserts by externalId and records every sample', () async {
      final g = FakeHealthPlatformGateway(seedSamples: [flow(1, id: 'a')]);
      await g.write([flow(1, id: 'a', src: HealthDataSource.healthConnect)]);
      await g.write([flow(2, id: 'b')]);
      await g.write([flow(3)]); // no id → always an insert

      expect(g.writes, hasLength(3));
      final ids = g.samples.map((s) => s.externalId).toList();
      expect(ids, containsAll(['a', 'b', null]));
      expect(g.samples.where((s) => s.externalId == 'a'), hasLength(1));
      expect(
        g.samples.firstWhere((s) => s.externalId == 'a').source,
        HealthDataSource.healthConnect,
      );
    });

    test('delete removes only the matching type in range', () async {
      final g = FakeHealthPlatformGateway(
        seedSamples: [
          flow(1, id: 'a'),
          flow(15, id: 'b'),
        ],
      );
      await g.delete(
        type: HealthSampleType.menstrualFlow,
        from: DateTime(2026, 6, 10),
        to: DateTime(2026, 6, 30),
      );
      expect(g.samples.map((s) => s.externalId), ['a']);
    });
  });
}
