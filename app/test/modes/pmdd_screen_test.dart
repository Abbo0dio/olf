import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/correlation_chart.dart';
import 'package:olf_app/src/modes/pmdd_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));
  final todayDate = DateTime(today.year, today.month, today.day);

  Future<void> enablePmdd(AppDatabase db) =>
      DriftSettingsRepository(db).set(LifeStageMode.pmdd.settingKey, 'true');

  Future<void> openPmddScreen(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Life-stage & condition modes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Life-stage & condition modes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open PMDD'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open PMDD'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PMDD'), findsOneWidget);
  }

  /// Four periods 28 days apart (three completed cycles + the open one) with
  /// higher ratings only on luteal-phase days across them.
  Future<void> seedRatings(AppDatabase db) async {
    await enablePmdd(db);
    final periods = DriftPeriodRepository(db);
    for (final ago in const [112, 84, 56, 28]) {
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
      );
    }
    final pmdd = DriftPmddRatingRepository(db);
    for (final ago in const [95, 93, 91, 67, 65, 63, 39, 37, 35]) {
      await pmdd.rateDay(daysAgo(ago), const {
        PmddSymptom.irritability: SymptomSeverity.severe,
        PmddSymptom.lowMood: SymptomSeverity.moderate,
        PmddSymptom.bloating: SymptomSeverity.none,
      });
    }
  }

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
  }

  group('PMDD screen', () {
    testWidgets('renders the overlay chart and the luteal read when seeded', (
      tester,
    ) async {
      final db = memoryDb();
      await seedRatings(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPmddScreen(tester);
          expect(find.byType(CorrelationChart), findsWidgets);
          expect(
            find.text(pmddLutealSummary(PmddLutealRead.runsHigherInLuteal)),
            findsOneWidget,
          );
        },
      );
    });

    testWidgets('shows an empty state when nothing is rated', (tester) async {
      final db = memoryDb();
      await enablePmdd(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPmddScreen(tester);
          expect(find.text(pmddEmptyState), findsOneWidget);
          expect(find.byType(CorrelationChart), findsNothing);
        },
      );
    });

    testWidgets('carries the disclaimer and the not-a-diagnosis line', (
      tester,
    ) async {
      final db = memoryDb();
      await seedRatings(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPmddScreen(tester);
          expect(find.text(pmddNotDiagnosisLine), findsOneWidget);
          await scrollToBottom(tester);
          expect(find.text(pmddDisclaimer), findsOneWidget);
        },
      );
    });

    testWidgets('rates a day through the repository, storing none for the rest', (
      tester,
    ) async {
      final db = memoryDb();
      await enablePmdd(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPmddScreen(tester);
          await tester.tap(find.text('Rate today'));
          await tester.pumpAndSettle();

          // Set the first item (Irritability) to Severe; leave the rest on None.
          await tester.tap(
            find.descendant(
              of: find.byType(SegmentedButton<SymptomSeverity>).first,
              matching: find.text('Severe'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          // Written through the real repository — one row per item, `none`
          // included.
          final ratings = await DriftPmddRatingRepository(
            db,
          ).ratingsOn(todayDate);
          expect(ratings[PmddSymptom.irritability], SymptomSeverity.severe);
          expect(ratings[PmddSymptom.fatigue], SymptomSeverity.none);
          expect(ratings.length, PmddSymptom.values.length);

          // And surfaced back on the screen.
          expect(find.textContaining('Today: rated'), findsOneWidget);
        },
      );
    });
  });

  group('copy discipline (§9(12))', () {
    final blob = <String>[
      pmddIntro,
      pmddAcrossCycleHeading,
      pmddNotDiagnosisLine,
      pmddEmptyState,
      pmddSheetIntro,
      pmddDisclaimer,
      pmddDaySummary(const {PmddSymptom.irritability: SymptomSeverity.severe}),
      pmddDaySummary(const {PmddSymptom.bloating: SymptomSeverity.none}),
      for (final r in PmddLutealRead.values) pmddLutealSummary(r),
      for (final r in PmddLutealRead.values) pmddLutealSummaryRedacted(r),
    ];

    test('no verdict or DRSP-style language', () {
      for (final line in blob) {
        final lower = line.toLowerCase();
        // Verdict phrasings — a diagnosis stated as fact or likelihood.
        expect(lower, isNot(contains('you likely have')), reason: line);
        expect(lower, isNot(contains('you may have')), reason: line);
        expect(lower, isNot(contains('you probably have')), reason: line);
        expect(lower, isNot(contains('this is pmdd')), reason: line);
        expect(lower, isNot(contains('confirms pmdd')), reason: line);
        // No DRSP score / clinical threshold framing.
        expect(lower, isNot(contains('drsp')), reason: line);
        expect(lower, isNot(contains('threshold')), reason: line);
        expect(lower, isNot(contains('diagnostic criteria')), reason: line);
        expect(lower, isNot(contains('p-value')), reason: line);
        expect(lower, isNot(contains('statistically')), reason: line);
      }
    });

    test('no numeric score anywhere in the copy', () {
      final scoreLike = RegExp(r'\d+\s*(%|/\s*100|out of 100|-\s*100|points?)');
      for (final line in blob) {
        expect(scoreLike.hasMatch(line), isFalse, reason: line);
      }
    });

    test('the framing lines are explicitly non-diagnostic', () {
      final intro = pmddIntro.toLowerCase();
      expect(intro, contains('not a score'));
      expect(intro, contains('not a diagnosis'));
      final line = pmddNotDiagnosisLine.toLowerCase();
      expect(line, contains('not a pmdd test'));
      expect(line, contains('clinician'));
    });
  });
}
