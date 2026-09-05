import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 3, 10, 6, 45);

  HealthSample bbt({
    double value = 36.5,
    HealthDataSource source = HealthDataSource.appleHealth,
    String? externalId = 'hk-1',
  }) => HealthSample.point(
    type: HealthSampleType.basalBodyTemperature,
    at: at,
    value: value,
    unit: HealthUnit.celsius,
    source: source,
    externalId: externalId,
  );

  group('HealthSample', () {
    test('point sample pins endAt to startAt', () {
      final s = bbt();
      expect(s.startAt, at);
      expect(s.endAt, at);
      expect(s.isPointSample, isTrue);
      expect(s.day, DateTime(2026, 3, 10));
    });

    test('interval sample keeps a distinct endAt', () {
      final s = HealthSample(
        type: HealthSampleType.sleep,
        startAt: DateTime(2026, 3, 10, 23),
        endAt: DateTime(2026, 3, 11, 6, 30),
        value: 450,
        unit: HealthUnit.minutes,
        source: HealthDataSource.healthConnect,
      );
      expect(s.isPointSample, isFalse);
      expect(s.day, DateTime(2026, 3, 10));
      expect(s.externalId, isNull);
    });

    test('value equality covers every field', () {
      expect(bbt(), equals(bbt()));
      expect(bbt().hashCode, bbt().hashCode);

      expect(bbt(value: 36.6), isNot(equals(bbt())));
      expect(bbt(source: HealthDataSource.healthConnect), isNot(equals(bbt())));
      expect(bbt(externalId: 'hk-2'), isNot(equals(bbt())));
      expect(bbt(externalId: null), isNot(equals(bbt())));
    });

    test('copyWith replaces one field and can clear the external id', () {
      final s = bbt();
      expect(s.copyWith(value: 37.0).value, 37.0);
      expect(s.copyWith(value: 37.0).externalId, 'hk-1');
      expect(s.copyWith(clearExternalId: true).externalId, isNull);
      expect(
        s.copyWith(source: HealthDataSource.manual).source,
        HealthDataSource.manual,
      );
    });

    test('rejects an endAt before startAt', () {
      expect(
        () => HealthSample(
          type: HealthSampleType.sleep,
          startAt: DateTime(2026, 3, 11),
          endAt: DateTime(2026, 3, 10),
          value: 1,
          unit: HealthUnit.minutes,
          source: HealthDataSource.manual,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a unit that does not match the type', () {
      expect(
        () => HealthSample.point(
          type: HealthSampleType.menstrualFlow,
          at: at,
          value: 2,
          unit: HealthUnit.celsius,
          source: HealthDataSource.manual,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HealthSample.point(
          type: HealthSampleType.wristTemperature,
          at: at,
          value: 36.2,
          unit: HealthUnit.minutes,
          source: HealthDataSource.appleHealth,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'accepts every declared type with its natural unit (extensibility)',
      () {
        const unitFor = {
          HealthSampleType.menstrualFlow: HealthUnit.flowLevel,
          HealthSampleType.basalBodyTemperature: HealthUnit.celsius,
          HealthSampleType.bodyTemperature: HealthUnit.celsius,
          HealthSampleType.wristTemperature: HealthUnit.celsius,
          HealthSampleType.sleep: HealthUnit.minutes,
        };
        // Every enum value is covered by the map — a new type breaks this test
        // until its unit rule is added.
        expect(unitFor.keys.toSet(), HealthSampleType.values.toSet());
        for (final type in HealthSampleType.values) {
          final s = HealthSample.point(
            type: type,
            at: at,
            value: 1,
            unit: unitFor[type]!,
            source: HealthDataSource.manual,
          );
          expect(s.type, type);
        }
      },
    );
  });

  group('healthDataSourceFromStorage', () {
    test('round-trips every enum name', () {
      for (final source in HealthDataSource.values) {
        expect(healthDataSourceFromStorage(source.name), source);
      }
    });

    test('maps null / unknown / legacy tokens to manual', () {
      expect(healthDataSourceFromStorage(null), HealthDataSource.manual);
      expect(healthDataSourceFromStorage(''), HealthDataSource.manual);
      expect(healthDataSourceFromStorage('garmin'), HealthDataSource.manual);
      expect(healthDataSourceFromStorage('MANUAL'), HealthDataSource.manual);
    });
  });
}
