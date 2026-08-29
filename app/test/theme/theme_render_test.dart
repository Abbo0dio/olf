import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// "Renders correctly in both themes" (p1.9 acceptance) as a robust check:
/// every main screen pumps under `olfTheme(light)` and `olfTheme(dark)` with no
/// exception and no `RenderFlex` overflow (both surface as a caught
/// `FlutterError`), and the resolved brightness is what we asked for. Pixel
/// goldens are deferred — see DEVELOPMENT_PLAN.md §9.
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  void expectRenderedAt(WidgetTester tester, Brightness brightness) {
    expect(tester.takeException(), isNull);
    final ctx = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, brightness);
    expect(olfTheme(brightness).brightness, brightness);
  }

  for (final brightness in Brightness.values) {
    final label = brightness.name;

    testWidgets('$label — home, calendar with data, day sheet, and meds', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final today = DateTime.now();
      final db = memoryDb();
      await DriftPeriodRepository(
        db,
      ).addPeriod(PeriodDraft(start: daysAgo(34), end: daysAgo(30)));
      await DriftPeriodRepository(
        db,
      ).addPeriod(PeriodDraft(start: daysAgo(6), end: daysAgo(3)));

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('History'), findsOneWidget);
          expectRenderedAt(tester, brightness);

          // Day-log sheet for a non-period day.
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, no period logged'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Day log — ${formatDay(today)}'), findsOneWidget);
          expectRenderedAt(tester, brightness);
          await tester.tapAt(const Offset(20, 20)); // dismiss the sheet
          await tester.pumpAndSettle();

          // Meds & reminders.
          await tester.tap(find.byTooltip('Medications & reminders'));
          await tester.pumpAndSettle();
          expect(find.text('Medications & reminders'), findsOneWidget);
          expectRenderedAt(tester, brightness);
        },
      );
    });

    testWidgets('$label — settings (appearance + pronouns + lock)', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpOlf(
        tester,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          expect(find.text('Appearance'), findsOneWidget);
          expect(find.text('Pronouns'), findsOneWidget);
          expectRenderedAt(tester, brightness);
        },
      );
    });

    testWidgets('$label — first-run explainer', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpOlf(
        tester,
        onboarded: false,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          expect(find.text('A few things first'), findsOneWidget);
          expectRenderedAt(tester, brightness);
        },
      );
    });

    testWidgets('$label — PIN unlock screen', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpOlf(
        tester,
        pinStore: FakePinStore(
          derivePinCredential('1379', iterations: 400, random: Random(1)),
        ),
        overrides: [dbOverride(memoryDb())],
        body: () async {
          expect(find.text('Enter your PIN'), findsOneWidget);
          expectRenderedAt(tester, brightness);
        },
      );
    });
  }
}
