import 'package:flutter_test/flutter_test.dart';

/// p5.1b — Dynamic Type / text scaling harness.
///
/// [textScales] is the sweep the acceptance criteria name: 1.0 (baseline),
/// 1.5, and 2.0 (the OS's largest common setting). Driving the platform
/// dispatcher's text-scale test value is what feeds `MediaQuery.of(context)
/// .textScaler` for a full-app `pumpOlf` — `MaterialApp` builds its own
/// `MediaQuery.fromView`, so wrapping the tree in a `MediaQuery` widget would
/// be ignored.
const List<double> textScales = <double>[1.0, 1.5, 2.0];

/// Set the OS text scale for the rest of this test (cleared on teardown). Call
/// **before** pumping the app.
void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Fail if the last frame produced a layout error — a `RenderFlex` overflow
/// ("A RenderFlex overflowed by … pixels"), an unbounded-constraints error, or
/// any other `FlutterError` surfaced during layout/paint. `flutter_test`
/// records these and rethrows an untaken one at test end; taking it here gives
/// a checkpoint with the surface + scale in the message. A non-layout exception
/// is rethrown untouched.
void expectNoOverflow(WidgetTester tester, {required String where}) {
  final Object? error = tester.takeException();
  if (error == null) return;
  final text = error.toString();
  final isLayout =
      text.contains('overflowed') ||
      text.contains('RenderFlex') ||
      text.contains('unbounded') ||
      text.contains('did not have a bounded');
  if (isLayout) {
    fail('layout overflow / error at $where:\n$text');
  }
  throw error;
}
