import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/flow_mapping.dart';
import 'package:olf_app/src/health/healthkit_gateway.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('olf/health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  /// Install a handler that records calls and returns [response] (or runs
  /// [respond] for per-call answers).
  void mockChannel({Object? response, Object? Function(MethodCall)? respond}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (respond != null) return respond(call);
      return response;
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const gateway = HealthKitGateway();

  final from = DateTime(2026, 1, 1);
  final to = DateTime(2026, 7, 1);

  group('read', () {
    test('decodes a HealthKit menstrual-flow category sample', () async {
      mockChannel(
        response: [
          {
            'type': 'menstrualFlow',
            'startMs': DateTime(2026, 3, 4).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 4).millisecondsSinceEpoch,
            'value': hkMenstrualFlowMedium.toDouble(),
            'externalId': 'HK-1',
          },
        ],
      );

      final out = await gateway.read(
        types: {HealthSampleType.menstrualFlow},
        from: from,
        to: to,
      );

      expect(out, hasLength(1));
      final s = out.single;
      expect(s.type, HealthSampleType.menstrualFlow);
      expect(s.unit, HealthUnit.flowLevel);
      expect(s.value, FlowIntensity.medium.index.toDouble());
      expect(s.source, HealthDataSource.appleHealth);
      expect(s.externalId, 'HK-1');
    });

    test('decodes a basal body temperature quantity sample in °C', () async {
      mockChannel(
        response: [
          {
            'type': 'basalBodyTemperature',
            'startMs': DateTime(2026, 3, 5).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 5).millisecondsSinceEpoch,
            'value': 36.62,
            'externalId': 'HK-2',
          },
        ],
      );

      final out = await gateway.read(
        types: {HealthSampleType.basalBodyTemperature},
        from: from,
        to: to,
      );

      expect(out.single.unit, HealthUnit.celsius);
      expect(out.single.value, 36.62);
    });

    test('decodes a passive Apple Watch wrist-temperature sample in °C '
        '(p8.1a)', () async {
      mockChannel(
        response: [
          {
            'type': 'wristTemperature',
            'startMs': DateTime(2026, 3, 7).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 7).millisecondsSinceEpoch,
            'value': 36.91,
            'externalId': 'HK-wrist-1',
          },
        ],
      );

      final out = await gateway.read(
        types: {HealthSampleType.wristTemperature},
        from: from,
        to: to,
      );

      expect(out, hasLength(1));
      final s = out.single;
      expect(s.type, HealthSampleType.wristTemperature);
      expect(s.unit, HealthUnit.celsius);
      expect(s.value, 36.91);
      expect(s.source, HealthDataSource.appleHealth);
      expect(s.externalId, 'HK-wrist-1');
      // The wrist token is forwarded to the native side on read.
      expect((calls.single.arguments as Map)['types'], ['wristTemperature']);
    });

    test(
      'a wrist-temperature sample is never written back out (p8.1a)',
      () async {
        mockChannel(response: null);
        await gateway.write([
          HealthSample.point(
            type: HealthSampleType.wristTemperature,
            at: DateTime(2026, 3, 7),
            value: 36.9,
            unit: HealthUnit.celsius,
            source: HealthDataSource.appleHealth,
          ),
        ]);
        expect(
          calls,
          isEmpty,
        ); // dropped by rawFromHealthSample, no channel call
      },
    );

    test(
      'carries a device tag from HKSource / HKDevice metadata (p8.2)',
      () async {
        mockChannel(
          response: [
            {
              'type': 'basalBodyTemperature',
              'startMs': DateTime(2026, 3, 8).millisecondsSinceEpoch,
              'endMs': DateTime(2026, 3, 8).millisecondsSinceEpoch,
              'value': 36.55,
              'externalId': 'HK-oura-1',
              'sourceDevice': 'Oura',
            },
            {
              'type': 'menstrualFlow',
              'startMs': DateTime(2026, 3, 9).millisecondsSinceEpoch,
              'endMs': DateTime(2026, 3, 9).millisecondsSinceEpoch,
              'value': hkMenstrualFlowMedium.toDouble(),
              'externalId': 'HK-garmin-1',
              'sourceDevice': 'Garmin Connect',
            },
          ],
        );

        final out = await gateway.read(
          types: {
            HealthSampleType.basalBodyTemperature,
            HealthSampleType.menstrualFlow,
          },
          from: from,
          to: to,
        );
        final byId = {for (final s in out) s.externalId: s};
        expect(byId['HK-oura-1']!.sourceDevice, 'Oura');
        expect(byId['HK-garmin-1']!.sourceDevice, 'Garmin Connect');
      },
    );

    test(
      'a blank device tag decodes as null, not an empty string (p8.2)',
      () async {
        mockChannel(
          response: [
            {
              'type': 'basalBodyTemperature',
              'startMs': DateTime(2026, 3, 8).millisecondsSinceEpoch,
              'endMs': DateTime(2026, 3, 8).millisecondsSinceEpoch,
              'value': 36.5,
              'externalId': 'HK-3',
              'sourceDevice': '   ',
            },
          ],
        );
        final out = await gateway.read(
          types: {HealthSampleType.basalBodyTemperature},
          from: from,
          to: to,
        );
        expect(out.single.sourceDevice, isNull);
      },
    );

    test('drops the HealthKit "no flow" marker', () async {
      mockChannel(
        response: [
          {
            'type': 'menstrualFlow',
            'startMs': DateTime(2026, 3, 6).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 6).millisecondsSinceEpoch,
            'value': hkMenstrualFlowNone.toDouble(),
          },
        ],
      );

      final out = await gateway.read(
        types: {HealthSampleType.menstrualFlow},
        from: from,
        to: to,
      );
      expect(out, isEmpty);
    });

    test(
      'never touches the channel for an unsupported-only type set',
      () async {
        mockChannel(response: const []);
        final out = await gateway.read(
          // Both genuinely unmapped: `wristTemperature` became supported in
          // p8.1a, so `bodyTemperature` + `sleep` are the unsupported pair now.
          types: {HealthSampleType.sleep, HealthSampleType.bodyTemperature},
          from: from,
          to: to,
        );
        expect(out, isEmpty);
        expect(calls, isEmpty);
      },
    );

    test('forwards only the supported subset of a mixed type set', () async {
      mockChannel(response: const []);
      await gateway.read(
        types: {HealthSampleType.menstrualFlow, HealthSampleType.sleep},
        from: from,
        to: to,
      );
      expect(calls.single.method, 'read');
      expect((calls.single.arguments as Map)['types'], ['menstrualFlow']);
    });
  });

  group('authorization', () {
    test('parses the granted status string', () async {
      mockChannel(response: 'granted');
      final status = await gateway.requestAuthorization({
        HealthSampleType.menstrualFlow,
        HealthSampleType.basalBodyTemperature,
      }, access: HealthAccess.readWrite);
      expect(status, HealthAuthStatus.granted);
      expect(calls.single.method, 'requestAuthorization');
    });

    test(
      'an unsupported-only request is denied without a channel call',
      () async {
        mockChannel(response: 'granted');
        final status = await gateway.requestAuthorization({
          HealthSampleType.sleep,
        }, access: HealthAccess.read);
        expect(status, HealthAuthStatus.denied);
        expect(calls, isEmpty);
      },
    );
  });

  group('write', () {
    test('encodes flow ordinal to the HealthKit value and drops '
        'unmapped types', () async {
      mockChannel(response: null);
      await gateway.write([
        HealthSample.point(
          type: HealthSampleType.menstrualFlow,
          at: DateTime(2026, 3, 7),
          value: FlowIntensity.heavy.index.toDouble(),
          unit: HealthUnit.flowLevel,
          source: HealthDataSource.manual,
        ),
        HealthSample.point(
          type: HealthSampleType.sleep,
          at: DateTime(2026, 3, 7),
          value: 420,
          unit: HealthUnit.minutes,
          source: HealthDataSource.manual,
        ),
      ]);

      final samples =
          (calls.single.arguments as Map)['samples'] as List<Object?>;
      expect(samples, hasLength(1));
      expect((samples.single as Map)['type'], 'menstrualFlow');
      expect((samples.single as Map)['value'], hkMenstrualFlowHeavy.toDouble());
    });

    test('a write of only unmapped types never calls the channel', () async {
      mockChannel(response: null);
      await gateway.write([
        HealthSample.point(
          type: HealthSampleType.bodyTemperature,
          at: DateTime(2026, 3, 7),
          value: 37.0,
          unit: HealthUnit.celsius,
          source: HealthDataSource.manual,
        ),
      ]);
      expect(calls, isEmpty);
    });
  });

  group('delete', () {
    test('is a no-op for an unsupported type', () async {
      mockChannel(response: null);
      await gateway.delete(type: HealthSampleType.sleep, from: from, to: to);
      expect(calls, isEmpty);
    });

    test('forwards a supported delete', () async {
      mockChannel(response: null);
      await gateway.delete(
        type: HealthSampleType.basalBodyTemperature,
        from: from,
        to: to,
      );
      expect(calls.single.method, 'delete');
      expect((calls.single.arguments as Map)['type'], 'basalBodyTemperature');
    });
  });

  group('platform unavailable', () {
    // No mock handler installed → the binding throws MissingPluginException,
    // which the channel wrapper turns into HealthPlatformUnavailable.
    test('read surfaces HealthPlatformUnavailable', () {
      expect(
        () => gateway.read(
          types: {HealthSampleType.menstrualFlow},
          from: from,
          to: to,
        ),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
    });

    test('requestAuthorization surfaces HealthPlatformUnavailable', () {
      expect(
        () => gateway.requestAuthorization({
          HealthSampleType.menstrualFlow,
        }, access: HealthAccess.readWrite),
        throwsA(isA<HealthPlatformUnavailable>()),
      );
    });

    test(
      'a native PlatformException also becomes HealthPlatformUnavailable',
      () {
        mockChannel(
          respond: (_) =>
              throw PlatformException(code: 'boom', message: 'nope'),
        );
        expect(
          () => gateway.read(
            types: {HealthSampleType.basalBodyTemperature},
            from: from,
            to: to,
          ),
          throwsA(isA<HealthPlatformUnavailable>()),
        );
      },
    );
  });

  test('isAvailable is true wherever this gateway is bound', () {
    expect(gateway.isAvailable, isTrue);
  });
}
