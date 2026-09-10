import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/birth_control_recalibration_content.dart';
import 'package:olf_app/src/modes/perimenopause_format.dart';
import 'package:olf_app/src/prediction/forecast_area.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r1 — the forecast area is one widget that renders **exactly one** child, by a
/// fixed priority: birth-control recalibration > perimenopause paused >
/// pregnancy mode (nothing) > overdue check-in > forecast card > nothing.
///
/// Priorities 1–3 are the conditions that withheld the prediction card in the
/// pre-consolidation code, so this is a zero-behaviour-change refactor: an
/// overdue prediction under any of them still shows the mode's note, never the
/// check-in. The one consolidation win is that recalibration + a perimenopause
/// gap collapse to one card + one secondary line instead of two stacked notes.
void main() {
  final today = DateTime.now();
  DateTime at(int daysFromToday) => DateTime(
    today.year,
    today.month,
    today.day,
  ).add(Duration(days: daysFromToday));

  CyclePrediction upcoming() => CyclePrediction(
    nextPeriod: DateRange(at(24), at(32)),
    nextPeriodExpected: at(28),
    fertileWindow: DateRange(at(10), at(16)),
    confidence: PredictionConfidence.high,
    basedOnCycles: 4,
    status: PredictionStatus.upcoming,
    daysPastExpected: null,
  );

  CyclePrediction overdue() => CyclePrediction(
    nextPeriod: DateRange(at(-6), at(-1)),
    nextPeriodExpected: at(-3),
    fertileWindow: DateRange(at(-20), at(-14)),
    confidence: PredictionConfidence.medium,
    basedOnCycles: 3,
    status: PredictionStatus.overdue,
    daysPastExpected: 3,
  );

  ForecastArea area({
    CyclePrediction? prediction,
    bool bcRecalActive = false,
    bool perimenopauseGapSuppress = false,
    bool pregnancyModeOn = false,
    bool reduceSpoken = false,
  }) => ForecastArea(
    prediction: prediction,
    bcRecalActive: bcRecalActive,
    perimenopauseGapSuppress: perimenopauseGapSuppress,
    pregnancyModeOn: pregnancyModeOn,
    reduceSpoken: reduceSpoken,
    onLogPeriodStart: () {},
    onDismissRecalibration: () {},
  );

  Future<void> pumpArea(WidgetTester tester, ForecastArea widget) =>
      tester.pumpWidget(
        MaterialApp(
          theme: olfTheme(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: widget)),
        ),
      );

  const recalNote = BirthControlRecalibrationContent.predictionCardNote;

  group('one branch at a time', () {
    testWidgets('5. forecast card — prediction, no modes', (tester) async {
      await pumpArea(tester, area(prediction: upcoming()));
      expect(find.text('Next period'), findsOneWidget);
      expect(find.text('Fertile window (estimate)'), findsOneWidget);
      expect(find.text('Period check-in'), findsNothing);
    });

    testWidgets('4. overdue check-in wins over the forecast half (no modes)', (
      tester,
    ) async {
      await pumpArea(tester, area(prediction: overdue()));
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text('Log period start'), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      expect(find.textContaining('Fertile window'), findsNothing);
    });

    testWidgets('1. birth-control recalibration note (no prediction yet)', (
      tester,
    ) async {
      await pumpArea(tester, area(bcRecalActive: true));
      expect(find.text(recalNote), findsOneWidget);
      expect(find.text('Learn more'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('1. recalibration beats a non-overdue forecast', (
      tester,
    ) async {
      await pumpArea(tester, area(prediction: upcoming(), bcRecalActive: true));
      expect(find.text(recalNote), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
    });

    testWidgets(
      '1. recalibration beats an OVERDUE prediction — no check-in, no line',
      (tester) async {
        await pumpArea(
          tester,
          area(prediction: overdue(), bcRecalActive: true),
        );
        expect(find.text('Learn more'), findsOneWidget); // the recal card
        expect(find.text('Period check-in'), findsNothing);
        expect(find.text('Next period'), findsNothing);
        // No secondary line — nothing lower-priority carries verbatim copy here.
        expect(find.text(perimenopauseForecastSuppressedNote), findsNothing);
      },
    );

    testWidgets('2. perimenopause paused note', (tester) async {
      await pumpArea(
        tester,
        area(prediction: upcoming(), perimenopauseGapSuppress: true),
      );
      expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      expect(find.text('Period check-in'), findsNothing);
    });

    testWidgets(
      '2. perimenopause gap beats an OVERDUE prediction — no check-in',
      (tester) async {
        await pumpArea(
          tester,
          area(prediction: overdue(), perimenopauseGapSuppress: true),
        );
        expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
        expect(find.text('Period check-in'), findsNothing);
        expect(find.text('Log period start'), findsNothing);
      },
    );

    testWidgets('3. pregnancy mode → nothing, even with a prediction', (
      tester,
    ) async {
      await pumpArea(
        tester,
        area(prediction: overdue(), pregnancyModeOn: true),
      );
      expect(find.text('Next period'), findsNothing);
      expect(find.text('Period check-in'), findsNothing);
      expect(tester.getSize(find.byType(ForecastArea)).height, 0);
    });

    testWidgets('6. no prediction, no modes → nothing', (tester) async {
      await pumpArea(tester, area());
      expect(tester.getSize(find.byType(ForecastArea)).height, 0);
    });
  });

  group(
    'recalibration + perimenopause gap → one card + one secondary line',
    () {
      testWidgets(
        'the recalibration card shows the paused note as a sub-line',
        (tester) async {
          await pumpArea(
            tester,
            area(bcRecalActive: true, perimenopauseGapSuppress: true),
          );
          expect(find.text('Learn more'), findsOneWidget); // the recal card
          expect(
            find.text(perimenopauseForecastSuppressedNote),
            findsOneWidget,
          );
          expect(find.text('Period check-in'), findsNothing);
          expect(find.text('Next period'), findsNothing);
        },
      );
    },
  );

  testWidgets(
    'invariant: every suppression + an overdue prediction → one card, one line',
    (tester) async {
      await pumpArea(
        tester,
        area(
          prediction: overdue(),
          bcRecalActive: true,
          perimenopauseGapSuppress: true,
          pregnancyModeOn: true,
        ),
      );
      // Priority 1 (recalibration) is the single card shown.
      expect(find.text('Learn more'), findsOneWidget);
      // The overdue check-in the wrong ordering would surface is suppressed.
      expect(find.text('Period check-in'), findsNothing);
      expect(find.text('Next period'), findsNothing);
      // Exactly one secondary line — the perimenopause note, once.
      expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
    },
  );

  group('on the real home screen', () {
    DateTime daysAgo(int n) => DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: n));

    Future<void> seedStart(AppDatabase db, DateTime start) =>
        DriftPeriodRepository(db).addPeriod(
          PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
        );

    testWidgets(
      'several suppression modes on at once → a single forecast-area card',
      (tester) async {
        final db = memoryDb();
        // A regular history far in the past → the prediction is overdue and a
        // perimenopause gap is in play (same fixture as
        // perimenopause_screen_test.dart "long absence: forecast is paused").
        var start = daysAgo(400 + 28 * 6);
        for (var i = 0; i < 6; i++) {
          await seedStart(db, start);
          start = start.add(const Duration(days: 28));
        }
        final settings = DriftSettingsRepository(db);
        await settings.set(LifeStageMode.perimenopause.settingKey, 'true');
        await settings.set(LifeStageMode.birthControlSwitch.settingKey, 'true');
        await settings.set(LifeStageMode.pregnancy.settingKey, 'true');
        await DriftBirthControlRepository(db).switchTo(BirthControlMethod.pill);

        await pumpOlf(
          tester,
          overrides: [dbOverride(db)],
          body: () async {
            // Recalibration (priority 1) wins; no check-in, no forecast.
            expect(find.byType(ForecastArea), findsOneWidget);
            expect(find.text('Learn more'), findsOneWidget);
            expect(find.text('Period check-in'), findsNothing);
            expect(find.text('Next period'), findsNothing);
            // The perimenopause note appears exactly once — as the sub-line.
            expect(
              find.text(perimenopauseForecastSuppressedNote),
              findsOneWidget,
            );
          },
        );
      },
    );

    testWidgets('_CorrectionNotice still renders above the forecast area', (
      tester,
    ) async {
      final db = memoryDb();
      for (final ago in const [104, 76, 48, 20]) {
        await seedStart(db, daysAgo(ago));
      }

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Next period'), findsOneWidget);

          // Delete the most recent period (Calendar history row) → a correction
          // notice appears back on Home, above the forecast area.
          await switchTab(tester, 'Calendar');
          await tester.tap(find.byTooltip('Delete period').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
          await tester.pumpAndSettle();
          await switchTab(tester, 'Home');

          final notice = find.bySemanticsLabel(
            RegExp('Your correction was applied'),
          );
          expect(notice, findsOneWidget);
          expect(find.byType(ForecastArea), findsOneWidget);
          // The transient notice sits above whatever the forecast area shows.
          expect(
            tester.getTopLeft(notice).dy,
            lessThan(tester.getTopLeft(find.byType(ForecastArea)).dy),
          );
        },
      );
    });
  });

  group('platform reduce-motion flag', () {
    void useReduceMotion(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('a swap shows the right card instantly, no animation widgets', (
      tester,
    ) async {
      useReduceMotion(tester);
      await pumpArea(tester, area(prediction: upcoming()));
      expect(find.text('Next period'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);

      await pumpArea(tester, area(bcRecalActive: true));
      expect(find.text('Learn more'), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('with motion, the swap mounts AnimatedSize and settles on the '
        'note', (tester) async {
      await pumpArea(tester, area(prediction: upcoming()));
      expect(find.text('Next period'), findsOneWidget);

      await pumpArea(tester, area(bcRecalActive: true));
      expect(
        find.descendant(
          of: find.byType(ForecastArea),
          matching: find.byType(AnimatedSize),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.text('Learn more'), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
    });
  });
}
