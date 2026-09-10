import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/birth_control_recalibration_content.dart';
import 'package:olf_app/src/prediction/forecast_area.dart';
import 'package:olf_app/src/widgets/animated_reveal.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r5b — the three conditional home cards (forecast area swaps, the transient
/// correction notice, the mode-chip strip) under both motion modes:
///
/// * **Reduce-motion on** (the OS flag): no AnimatedSize / FadeTransition is
///   mounted anywhere on Home — nothing can run; the right state shows
///   immediately.
/// * **Motion on (default)**: the same cards run through AnimatedReveal and
///   still settle on the right state.
void main() {
  void useReduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  /// Four 28-day cycles back from today — enough for a prediction.
  Future<void> seedRegularHistory(AppDatabase db) async {
    for (final ago in const [104, 76, 48, 20]) {
      await DriftPeriodRepository(
        db,
      ).addPeriod(PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)));
    }
  }

  group('platform reduce-motion flag ON', () {
    testWidgets('forecast swap (recalibration on): note replaces the card '
        'instantly, with no animation widgets', (tester) async {
      useReduceMotion(tester);
      final db = memoryDb();
      await seedRegularHistory(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Next period'), findsOneWidget);
          expect(find.byType(AnimatedSize), findsNothing);

          // Birth-control recalibration turns the forecast card into the note
          // (the swap AnimatedReveal animates when motion is on).
          final settings = DriftSettingsRepository(db);
          await settings.set(
            LifeStageMode.birthControlSwitch.settingKey,
            'true',
          );
          await DriftBirthControlRepository(
            db,
          ).switchTo(BirthControlMethod.pill);
          await tester.pumpAndSettle();

          expect(
            find.text(BirthControlRecalibrationContent.predictionCardNote),
            findsOneWidget,
          );
          expect(find.text('Next period'), findsNothing);
          expect(find.byType(AnimatedSize), findsNothing);
        },
      );
    });

    testWidgets('correction notice after a delete: present, but not animated', (
      tester,
    ) async {
      useReduceMotion(tester);
      final db = memoryDb();
      await seedRegularHistory(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(find.byTooltip('Delete period').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
          await tester.pumpAndSettle();
          await switchTab(tester, 'Home');

          expect(
            find.bySemanticsLabel(RegExp('Your correction was applied')),
            findsOneWidget,
          );
          expect(find.byType(AnimatedSize), findsNothing);
        },
      );
    });

    testWidgets(
      'mode-chip strip: chips appear instantly when a mode turns on',
      (tester) async {
        useReduceMotion(tester);
        final db = memoryDb();

        await pumpOlf(
          tester,
          overrides: [dbOverride(db)],
          body: () async {
            expect(find.widgetWithText(ActionChip, 'PCOS'), findsNothing);
            await DriftSettingsRepository(
              db,
            ).set(LifeStageMode.pcos.settingKey, 'true');
            await tester.pumpAndSettle();

            expect(find.widgetWithText(ActionChip, 'PCOS'), findsOneWidget);
            expect(find.byType(AnimatedSize), findsNothing);
          },
        );
      },
    );
  });

  group('motion on (default)', () {
    testWidgets('mode-chip strip runs through AnimatedReveal and settles', (
      tester,
    ) async {
      final db = memoryDb();

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await DriftSettingsRepository(
            db,
          ).set(LifeStageMode.pcos.settingKey, 'true');
          await tester.pumpAndSettle();

          expect(find.widgetWithText(ActionChip, 'PCOS'), findsOneWidget);
          // The strip is one of the home's AnimatedReveal mounts.
          expect(find.byType(AnimatedReveal), findsWidgets);
        },
      );
    });

    testWidgets('the correction notice animates in and is announced', (
      tester,
    ) async {
      final db = memoryDb();
      await seedRegularHistory(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Calendar');
          await tester.tap(find.byTooltip('Delete period').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
          await tester.pumpAndSettle();
          await switchTab(tester, 'Home');

          expect(
            find.bySemanticsLabel(RegExp('Your correction was applied')),
            findsOneWidget,
          );
          final notice = find.bySemanticsLabel(
            RegExp('Your correction was applied'),
          );
          // The notice sits above the forecast area (unchanged from r1).
          expect(
            tester.getTopLeft(notice).dy,
            lessThan(tester.getTopLeft(find.byType(ForecastArea)).dy),
          );
        },
      );
    });
  });
}
