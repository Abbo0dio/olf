import 'dart:io';

import 'package:test/test.dart';

/// Guard for `docs/health-platform-interop.md` (p6.3). The Google Fit APIs shut
/// down in 2026 and Health Connect is olf's only Android health path — that, and
/// the iOS-vs-Android capability asymmetry, has to stay written down. This test
/// fails the build if the doc goes missing or loses the Google Fit deprecation
/// note.
///
/// A plain `dart:io` test, picked up by the existing `core — unit tests` CI step
/// (same wiring as `dependency_audit_test.dart` / `threat_model_doc_test.dart`).
/// `dart test` runs with `core/` as CWD, so the repo root is one level up.
void main() {
  final doc = File('../docs/health-platform-interop.md');

  late String text;

  setUpAll(() {
    expect(
      doc.existsSync(),
      isTrue,
      reason: 'docs/health-platform-interop.md is missing (run from core/)',
    );
    text = doc.readAsStringSync();
  });

  test('is a real document, not a stub', () {
    expect(text.length, greaterThan(1000));
  });

  test('carries the Google Fit deprecation note', () {
    expect(text, contains('Google Fit'));
    expect(
      text.toLowerCase(),
      anyOf(contains('shut down'), contains('deprecat')),
      reason: 'must say the Google Fit APIs are gone',
    );
    expect(text, contains('2026'), reason: 'the Google Fit shutdown year');
  });

  test('names Health Connect as the Android path', () {
    expect(text, contains('Health Connect'));
    expect(text, contains('androidx.health.connect'));
  });

  test('records the iOS-vs-Android capability asymmetry', () {
    expect(text.toLowerCase(), contains('asymmetr'));
    expect(
      text.toLowerCase(),
      anyOf(contains('wrist'), contains('skintemperature')),
      reason: 'the wrist/skin-temperature example of the asymmetry',
    );
  });
}
