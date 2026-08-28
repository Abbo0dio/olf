// On-device integration test for the p0.4 slice: log → (relaunch) → still there
// → delete. Runs against the REAL encrypted database + platform secure storage.
//
//   flutter test integration_test/log_period_test.dart      # needs a device
//
// It is intentionally NOT in the CI `test` job — CI has no emulator/simulator.
// The equivalent persistence round-trip runs headless in
// `core/test/db/persistence_test.dart`; the widget flow runs in
// `app/test/widget_test.dart`. Wire this into CI when emulator CI is added.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olf_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log a period start, confirm Day 1, then remove it', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OlfApp()));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Fresh install (or already-empty): log today.
    if (find.text('Period started today').evaluate().isNotEmpty) {
      await tester.tap(find.text('Period started today'));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Day '), findsOneWidget);

    // Simulate a relaunch by rebuilding the whole app from scratch.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const ProviderScope(child: OlfApp()));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.textContaining('Day '), findsOneWidget);

    // Clean up so re-runs start empty.
    await tester.tap(find.text('Remove this entry'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });
}
