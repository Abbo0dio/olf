// On-device integration test for the p1.5 slice (symptom logging), run in CI by
// the **nightly** workflow (.github/workflows/nightly-integration.yml) on an
// Android emulator and an iOS simulator. Not part of the PR-blocking `CI`
// workflow.
//
//   flutter test integration_test/log_symptoms_test.dart     # needs a device
//
// It exercises the real path: SQLCipher + the platform key store, the seeded
// symptom catalogue, and multi-day logging surfaced in "Recent symptoms". The
// headless equivalents that run on every PR are core/test/symptom/* and
// app/test/symptom/*.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olf_app/main.dart';
import 'package:olf_app/src/period/period_format.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> launch(
    WidgetTester tester,
    ProviderContainer container,
    bool Function() ready,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const OlfApp()),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (ready()) return;
    }
    fail('timed out waiting for home content to render');
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final today = DateTime.now();
  final other = today.day == 1
      ? DateTime(today.year, today.month, 2)
      : DateTime(today.year, today.month, 1);

  Finder cell(DateTime day, {int symptoms = 0}) => find.bySemanticsLabel(
    symptoms == 0
        ? '${formatDay(day)}, no period logged'
        : '${formatDay(day)}, no period logged, '
              '$symptoms symptom${symptoms == 1 ? '' : 's'}',
  );
  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  testWidgets('log symptoms on two days → both show under Recent symptoms', (
    tester,
  ) async {
    final recentHeading = find.text('Recent symptoms');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await launch(tester, container, () => recentHeading.evaluate().isNotEmpty);

    // --- day 1: today — Cramps + Fatigue ---
    await tapVisible(tester, cell(today));
    expect(find.text('Day log — ${formatDay(today)}'), findsOneWidget);
    await tapVisible(tester, chip('Cramps'));
    await tapVisible(tester, chip('Fatigue'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));

    // --- day 2: another day this month — Headache ---
    await tapVisible(tester, cell(other));
    await tapVisible(tester, chip('Headache'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));

    // --- both days are listed, newest first, with their names ---
    expect(recentHeading, findsOneWidget);
    expect(find.text('Cramps, Fatigue'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
    expect(find.text(formatDay(today)), findsWidgets);
    expect(find.text(formatDay(other)), findsWidgets);

    // --- clean up so the next nightly run starts empty ---
    await tapVisible(tester, cell(today, symptoms: 2));
    await tapVisible(tester, chip('Cramps'));
    await tapVisible(tester, chip('Fatigue'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));

    await tapVisible(tester, cell(other, symptoms: 1));
    await tapVisible(tester, chip('Headache'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Done'));

    expect(find.text('No symptoms logged yet.'), findsOneWidget);
  });
}
