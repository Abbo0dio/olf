import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('sourcePrecedenceTier — classifier', () {
    test('a value the user typed is always the manual tier', () {
      for (final wrist in [true, false]) {
        for (final dev in [null, 'com.ouraring.oura', 'whatever']) {
          expect(
            sourcePrecedenceTier(
              source: HealthDataSource.manual,
              isSleepingWrist: wrist,
              sourceDevice: dev,
            ),
            SourcePrecedenceTier.manual,
          );
        }
      }
    });

    test('an Apple-Watch sleeping-wrist reading is the wrist tier, whatever '
        'the device string says', () {
      expect(
        sourcePrecedenceTier(
          source: HealthDataSource.appleHealth,
          isSleepingWrist: true,
          sourceDevice: null,
        ),
        SourcePrecedenceTier.sleepingWrist,
      );
      // even if the platform tagged it with a known vendor name
      expect(
        sourcePrecedenceTier(
          source: HealthDataSource.appleHealth,
          isSleepingWrist: true,
          sourceDevice: 'com.ouraring.oura',
        ),
        SourcePrecedenceTier.sleepingWrist,
      );
    });

    test('an automatic reading with a recognised device tag is the '
        'attributed-device tier', () {
      expect(
        sourcePrecedenceTier(
          source: HealthDataSource.healthConnect,
          isSleepingWrist: false,
          sourceDevice: 'com.garmin.android.apps.connectmobile',
        ),
        SourcePrecedenceTier.attributedDevice,
      );
      expect(
        sourcePrecedenceTier(
          source: HealthDataSource.appleHealth,
          isSleepingWrist: false,
          sourceDevice: 'Oura',
        ),
        SourcePrecedenceTier.attributedDevice,
      );
    });

    test('an automatic reading with no / unrecognised device tag is the '
        'generic-platform tier', () {
      for (final dev in [null, '', '   ', 'com.acme.unknown', 'Random App']) {
        expect(
          sourcePrecedenceTier(
            source: HealthDataSource.appleHealth,
            isSleepingWrist: false,
            sourceDevice: dev,
          ),
          SourcePrecedenceTier.genericPlatform,
          reason: 'device tag: $dev',
        );
      }
    });
  });

  group('the order', () {
    test('manual > attributedDevice > sleepingWrist > genericPlatform', () {
      expect(SourcePrecedenceTier.manual.rank, 3);
      expect(SourcePrecedenceTier.attributedDevice.rank, 2);
      expect(SourcePrecedenceTier.sleepingWrist.rank, 1);
      expect(SourcePrecedenceTier.genericPlatform.rank, 0);

      expect(
        SourcePrecedenceTier.manual.outranks(
          SourcePrecedenceTier.attributedDevice,
        ),
        isTrue,
      );
      expect(
        SourcePrecedenceTier.attributedDevice.outranks(
          SourcePrecedenceTier.sleepingWrist,
        ),
        isTrue,
      );
      expect(
        SourcePrecedenceTier.sleepingWrist.outranks(
          SourcePrecedenceTier.genericPlatform,
        ),
        isTrue,
      );
    });

    test('compareTiers is a total order, antisymmetric', () {
      final tiers = SourcePrecedenceTier.values;
      for (final a in tiers) {
        expect(compareTiers(a, a), 0);
        for (final b in tiers) {
          expect(compareTiers(a, b).sign, -compareTiers(b, a).sign);
          expect(compareTiers(a, b) > 0, a.rank > b.rank);
        }
      }
    });

    test('outranks is irreflexive and asymmetric', () {
      for (final a in SourcePrecedenceTier.values) {
        expect(a.outranks(a), isFalse);
        for (final b in SourcePrecedenceTier.values) {
          if (a.outranks(b)) expect(b.outranks(a), isFalse);
        }
      }
    });
  });
}
