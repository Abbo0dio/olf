import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('knownVendorLabel', () {
    test('null / blank → null', () {
      expect(knownVendorLabel(null), isNull);
      expect(knownVendorLabel(''), isNull);
      expect(knownVendorLabel('   '), isNull);
    });

    test('known Health Connect package ids resolve on prefix', () {
      expect(knownVendorLabel('com.ouraring.oura'), 'Oura');
      expect(
        knownVendorLabel('com.garmin.android.apps.connectmobile'),
        'Garmin',
      );
      expect(knownVendorLabel('com.withings.wiscale2'), 'Withings');
      expect(knownVendorLabel('COM.OURARING.OURA'), 'Oura'); // case-insensitive
      expect(knownVendorLabel(' com.ouraring.oura '), 'Oura'); // trimmed
    });

    test('an unknown package id → null (not a best-effort guess)', () {
      expect(knownVendorLabel('com.acme.ringapp'), isNull);
      expect(knownVendorLabel('io.example.tracker'), isNull);
    });

    test('known iOS plain names resolve from the allow-list', () {
      expect(knownVendorLabel('Oura'), 'Oura');
      expect(knownVendorLabel('Garmin Connect'), 'Garmin');
      expect(knownVendorLabel('withings health mate'), 'Withings');
    });

    test('an unknown plain name → null', () {
      expect(knownVendorLabel('My Cool Thermometer'), isNull);
      expect(knownVendorLabel('iPhone'), isNull);
    });
  });

  group('isAttributedDevice', () {
    test('true only for a recognised vendor tag', () {
      expect(isAttributedDevice('com.ouraring.oura'), isTrue);
      expect(isAttributedDevice('Garmin Connect'), isTrue);
      expect(isAttributedDevice(null), isFalse);
      expect(isAttributedDevice(''), isFalse);
      expect(isAttributedDevice('com.acme.ringapp'), isFalse);
      expect(isAttributedDevice('Some Phone'), isFalse);
    });
  });
}
