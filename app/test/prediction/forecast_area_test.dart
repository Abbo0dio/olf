import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/birth_control_recalibration_content.dart';
import 'package:olf_app/src/modes/perimenopause_format.dart';
import 'package:olf_app/src/prediction/forecast_area.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r1 — the forecast area is one widget that renders **exactly one** child, by a
/// fixed priority: overdue check-in > birth-control recalibration >
/// perimenopause paused > pregnancy mode (nothing) > forecast card > nothing.
/// A coinciding lower-priority condition adds one secondary line, never a
/// second card. These tests pin every branch and the single-child invariant.
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

    testWidgets('1. overdue check-in wins over the forecast half', (
      tester,
    ) async {
      await pumpArea(tester, area(prediction: overdue()));
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text('Log period start'), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      expect(find.textContaining('Fertile window'), findsNothing);
    });

    testWidgets('2. birth-control recalibration note (no prediction yet)', (
      tester,
    ) async {
      await pumpArea(tester, area(bcRecalActive: true));
      expect(find.text(recalNote), findsOneWidget);
      expect(find.text('Learn more'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('2. recalibration beats a non-overdue forecast', (
      tester,
    ) async {
      await pumpArea(tester, area(prediction: upcoming(), bcRecalActive: true));
      expect(find.text(recalNote), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
    });

    testWidgets('3. perimenopause paused note', (tester) async {
      await pumpArea(
        tester,
        area(prediction: upcoming(), perimenopauseGapSuppress: true),
      );
      expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      expect(find.text('Period check-in'), findsNothing);
    });

    testWidgets('4. pregnancy mode → nothing, even with a prediction', (
      tester,
    ) async {
      await pumpArea(
        tester,
        area(prediction: upcoming(), pregnancyModeOn: true),
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

  group('two conditions coincide → one extra secondary line, not a card', () {
    testWidgets('overdue + recalibration → overdue card + recal line', (
      tester,
    ) async {
      await pumpArea(tester, area(prediction: overdue(), bcRecalActive: true));
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text(recalNote), findsOneWidget); // the secondary line
      // …but not the standalone recalibration card.
      expect(find.text('Learn more'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('overdue + perimenopause gap → overdue card + paused line', (
      tester,
    ) async {
      await pumpArea(
        tester,
        area(prediction: overdue(), perimenopauseGapSuppress: true),
      );
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
    });

    testWidgets(
      'recalibration + perimenopause gap → recal card + paused line',
      (tester) async {
        await pumpArea(
          tester,
          area(bcRecalActive: true, perimenopauseGapSuppress: true),
        );
        expect(find.text('Learn more'), findsOneWidget); // the recal card
        expect(find.text(perimenopauseForecastSuppressedNote), findsOneWidget);
        expect(find.text('Period check-in'), findsNothing);
        expect(find.text('Next period'), findsNothing);
      },
    );
  });

  testWidgets(
    'invariant: every mode on at once → exactly one card, one secondary line',
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
      // Priority 1 (overdue) is the single card shown.
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text('Next period'), findsNothing);
      // No other card rendered.
      expect(find.text('Learn more'), findsNothing);
      // Exactly one secondary line — the highest-priority coinciding condition
      // (recalibration), and only it.
      expect(find.text(recalNote), findsOneWidget);
      expect(find.text(perimenopauseForecastSuppressedNote), findsNothing);
    },
  );

  testWidgets(
    'reduceSpoken: the secondary line is folded into the card semantics',
    (tester) async {
      await pumpArea(
        tester,
        area(prediction: overdue(), bcRecalActive: true, reduceSpoken: true),
      );
      // Visible copy is unchanged…
      expect(find.text('Period check-in'), findsOneWidget);
      expect(find.text(recalNote), findsOneWidget);
      // …and the redacted read-out still carries the secondary line.
      expect(
        find.bySemanticsLabel(
          RegExp('Period check-in available.*${RegExp.escape(recalNote)}'),
        ),
        findsOneWidget,
      );
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
      'several modes on at once still renders a single forecast-area card',
      (tester) async {
        final db = memoryDb();
        // A regular history far in the past → the prediction is overdue and a
        // perimenopause gap is in play.
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
            // Overdue check-in wins; no other forecast-area card co-renders.
            expect(find.text('Period check-in'), findsOneWidget);
            expect(find.text('Next period'), findsNothing);
            expect(find.text('Learn more'), findsNothing);
            expect(find.byType(ForecastArea), findsOneWidget);
            // The perimenopause note appears at most once (as a secondary line
            // here it is suppressed in favour of the recalibration line).
            expect(
              find.text(perimenopauseForecastSuppressedNote),
              findsNothing,
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

          // Delete the most recent period → a correction notice appears.
          await tester.tap(find.byTooltip('Delete period').first);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Delete'));
          await tester.pumpAndSettle();

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
}
