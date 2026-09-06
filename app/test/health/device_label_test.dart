import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/device_label.dart';

void main() {
  group('prettyDeviceLabel', () {
    test('null / blank tags return null', () {
      expect(prettyDeviceLabel(null), isNull);
      expect(prettyDeviceLabel(''), isNull);
      expect(prettyDeviceLabel('   '), isNull);
    });

    test('known Health Connect package ids map to a product name', () {
      expect(prettyDeviceLabel('com.ouraring.oura'), 'Oura');
      expect(
        prettyDeviceLabel('com.garmin.android.apps.connectmobile'),
        'Garmin',
      );
      expect(
        prettyDeviceLabel('com.google.android.apps.fitness'),
        'Google Fit',
      );
      expect(prettyDeviceLabel('com.withings.wiscale2'), 'Withings');
      expect(
        prettyDeviceLabel('COM.OURARING.OURA'),
        'Oura',
      ); // case-insensitive
    });

    test('an unknown package id falls back to a title-cased last segment', () {
      expect(prettyDeviceLabel('com.acme.ringapp'), 'Ringapp');
      expect(prettyDeviceLabel('io.example.tracker'), 'Tracker');
    });

    test('a plain iOS HKSource / HKDevice name passes through untouched', () {
      expect(prettyDeviceLabel('Oura'), 'Oura');
      expect(prettyDeviceLabel('Garmin Connect'), 'Garmin Connect');
      expect(prettyDeviceLabel('Withings Health Mate'), 'Withings Health Mate');
    });

    test('surrounding whitespace is trimmed', () {
      expect(prettyDeviceLabel('  Oura  '), 'Oura');
      expect(prettyDeviceLabel(' com.ouraring.oura '), 'Oura');
    });
  });
}
