import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/flow_mapping.dart';
import 'package:olf_app/src/health/health_connect_gateway.dart';
import 'package:olf_core/olf_core.dart';

/// `HealthConnectGateway` (p6.3) is the Android peer of `HealthKitGateway`
/// (p6.2). Both extend `MethodChannelHealthGateway` and speak the *same*
/// `olf/health` wire contract — HealthKit-native menstrual-flow integers and
/// °C temperatures — because the Kotlin bridge translates Health Connect's own
/// scale on the native side. So these tests mock the channel exactly like
/// `healthkit_gateway_test.dart` and assert the Dart end is unchanged, plus the
/// Android-only `runtimeAvailable()` SDK probe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('olf/health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void mockChannel({Object? response, Object? Function(MethodCall)? respond}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (respond != null) return respond(call);
      return response;
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const gateway = HealthConnectGateway();

  final from = DateTime(2026, 1, 1);
  final to = DateTime(2026, 7, 1);

  group('runtimeAvailable', () {
    test('reports what the channel isAvailable call returns', () async {
      mockChannel(response: true);
      expect(await gateway.runtimeAvailable(), isTrue);
      expect(calls.single.method, 'isAvailable');
    });

    test('is false when Health Connect is not installed', () async {
      mockChannel(response: false);
      expect(await gateway.runtimeAvailable(), isFalse);
    });

    test('is false when the channel is unimplemented', () async {
      // No mock handler → MissingPluginException, swallowed to `false`.
      expect(await gateway.runtimeAvailable(), isFalse);
    });

    test('isAvailable (the bound getter) is true on Android', () {
      expect(gateway.isAvailable, isTrue);
    });
  });

  group('read', () {
    test('decodes a menstrual-flow sample (wire = HealthKit scale)', () async {
      mockChannel(
        response: [
          {
            'type': 'menstrualFlow',
            'startMs': DateTime(2026, 3, 4).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 4).millisecondsSinceEpoch,
            'value': hkMenstrualFlowMedium.toDouble(),
            'externalId': 'HC-1',
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
      expect(s.source, HealthDataSource.healthConnect);
      expect(s.externalId, 'HC-1');
    });

    test('decodes a basal body temperature sample in °C', () async {
      mockChannel(
        response: [
          {
            'type': 'basalBodyTemperature',
            'startMs': DateTime(2026, 3, 5).millisecondsSinceEpoch,
            'endMs': DateTime(2026, 3, 5).millisecondsSinceEpoch,
            'value': 36.55,
            'externalId': 'HC-2',
          },
        ],
      );

      final out = await gateway.read(
        types: {HealthSampleType.basalBodyTemperature},
        from: from,
        to: to,
      );

      expect(out.single.unit, HealthUnit.celsius);
      expect(out.single.value, 36.55);
      expect(out.single.source, HealthDataSource.healthConnect);
    });

    test('drops the "no flow" marker', () async {
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
          types: {HealthSampleType.sleep, HealthSampleType.wristTemperature},
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
        types: {HealthSampleType.basalBodyTemperature, HealthSampleType.sleep},
        from: from,
        to: to,
      );
      expect(calls.single.method, 'read');
      expect((calls.single.arguments as Map)['types'], [
        'basalBodyTemperature',
      ]);
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
      expect((calls.single.arguments as Map)['access'], 'readWrite');
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
    test(
      'encodes flow ordinal to the wire value and drops unmapped types',
      () async {
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
        expect(
          (samples.single as Map)['value'],
          hkMenstrualFlowHeavy.toDouble(),
        );
      },
    );

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
        type: HealthSampleType.menstrualFlow,
        from: from,
        to: to,
      );
      expect(calls.single.method, 'delete');
      expect((calls.single.arguments as Map)['type'], 'menstrualFlow');
    });
  });

  group('platform unavailable', () {
    test('read surfaces HealthPlatformUnavailable when unimplemented', () {
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

  group('Health Connect ↔ wire flow-scale contract (reference)', () {
    // The Kotlin bridge translates Health Connect's flow scale
    // (FLOW_UNKNOWN=0, LIGHT=1, MEDIUM=2, HEAVY=3) to/from the HealthKit wire
    // scale this Dart codec consumes. These pin the wire end of that contract:
    // whatever integer the Kotlin side emits, the Dart codec must map it thus.
    test('wire values map to the expected FlowIntensity', () {
      expect(
        flowIntensityFromHk(hkMenstrualFlowUnspecified),
        FlowIntensity.spotting,
      );
      expect(flowIntensityFromHk(hkMenstrualFlowLight), FlowIntensity.light);
      expect(flowIntensityFromHk(hkMenstrualFlowMedium), FlowIntensity.medium);
      expect(flowIntensityFromHk(hkMenstrualFlowHeavy), FlowIntensity.heavy);
      expect(flowIntensityFromHk(hkMenstrualFlowNone), isNull);
    });

    test(
      'FlowIntensity maps back to the wire value the Kotlin side expects',
      () {
        expect(
          hkValueFromFlowIntensity(FlowIntensity.spotting),
          hkMenstrualFlowUnspecified,
        );
        expect(
          hkValueFromFlowIntensity(FlowIntensity.light),
          hkMenstrualFlowLight,
        );
        expect(
          hkValueFromFlowIntensity(FlowIntensity.medium),
          hkMenstrualFlowMedium,
        );
        expect(
          hkValueFromFlowIntensity(FlowIntensity.heavy),
          hkMenstrualFlowHeavy,
        );
      },
    );
  });
}
