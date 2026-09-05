import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/flow_mapping.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  group('flowIntensityFromHk', () {
    test('maps the three shared levels one-to-one', () {
      expect(flowIntensityFromHk(hkMenstrualFlowLight), FlowIntensity.light);
      expect(flowIntensityFromHk(hkMenstrualFlowMedium), FlowIntensity.medium);
      expect(flowIntensityFromHk(hkMenstrualFlowHeavy), FlowIntensity.heavy);
    });

    test('maps HealthKit "unspecified" to the lightest olf level', () {
      expect(
        flowIntensityFromHk(hkMenstrualFlowUnspecified),
        FlowIntensity.spotting,
      );
    });

    test('returns null for HealthKit "none" and anything unknown', () {
      expect(flowIntensityFromHk(hkMenstrualFlowNone), isNull);
      expect(flowIntensityFromHk(0), isNull);
      expect(flowIntensityFromHk(99), isNull);
    });
  });

  group('hkValueFromFlowIntensity', () {
    test('spotting goes out as "unspecified"', () {
      expect(
        hkValueFromFlowIntensity(FlowIntensity.spotting),
        hkMenstrualFlowUnspecified,
      );
    });

    test('light / medium / heavy round-trip exactly', () {
      for (final i in const [
        FlowIntensity.light,
        FlowIntensity.medium,
        FlowIntensity.heavy,
      ]) {
        expect(flowIntensityFromHk(hkValueFromFlowIntensity(i)), i);
      }
    });

    test('spotting round-trips through unspecified back to spotting', () {
      expect(
        flowIntensityFromHk(hkValueFromFlowIntensity(FlowIntensity.spotting)),
        FlowIntensity.spotting,
      );
    });
  });
}
