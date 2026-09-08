import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/correlation_chart.dart';
import 'package:olf_app/src/modes/perimenopause_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> enablePerimenopause(AppDatabase db) => DriftSettingsRepository(
    db,
  ).set(LifeStageMode.perimenopause.settingKey, 'true');

  Future<SymptomType> builtInType(AppDatabase db, String name) async {
    final types = await DriftSymptomRepository(db).activeTypes();
    return types.firstWhere((t) => t.name == name);
  }

  Future<void> openScreen(WidgetTester tester) async {
    // r3b: the Modes on/off entry moved from Settings to the Patterns tab.
    await switchTab(tester, 'Patterns');
    await tester.scrollUntilVisible(
      find.text('Life-stage & condition modes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Life-stage & condition modes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open Perimenopause'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open Perimenopause'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Perimenopause'), findsOneWidget);
  }

  Future<void> scrollDown(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
  }

  /// A history whose cycle-length spread widens over time, no missed-entry gap,
  /// with "Low mood" logged on luteal-phase days across recent cycles.
  Future<void> seedWideningWithSymptom(AppDatabase db) async {
    await enablePerimenopause(db);
    final periods = DriftPeriodRepository(db);
    var start = daysAgo(8 + 28 + 27 + 29 + 28 + 41 + 24 + 39);
    for (final gap in const [28, 27, 29, 28, 41, 24, 39]) {
      await periods.addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
      );
      start = start.add(Duration(days: gap));
    }
    await periods.addPeriod(
      PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
    );
    final lowMood = await builtInType(db, 'Low mood');
    for (var ago = 12; ago <= 120; ago += 12) {
      await DriftSymptomRepository(
        db,
      ).setSymptom(daysAgo(ago), lowMood.id, present: true);
    }
  }

  group('perimenopause screen', () {
    testWidgets('renders the transition read and a symptom timeline chart', (
      tester,
    ) async {
      final db = memoryDb();
      await seedWideningWithSymptom(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openScreen(tester);
          expect(find.text(perimenopauseTransitionHeading), findsOneWidget);
          expect(find.textContaining('becoming less regular'), findsOneWidget);
          expect(find.text('Low mood'), findsOneWidget);
          expect(find.byType(CorrelationChart), findsOneWidget);
        },
      );
    });

    testWidgets('excludes an unrelated built-in symptom from the timeline', (
      tester,
    ) async {
      final db = memoryDb();
      await seedWideningWithSymptom(db);
      final acne = await builtInType(db, 'Acne');
      for (var ago = 10; ago <= 90; ago += 10) {
        await DriftSymptomRepository(
          db,
        ).setSymptom(daysAgo(ago), acne.id, present: true);
      }
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openScreen(tester);
          expect(find.text('Low mood'), findsOneWidget);
          expect(find.text('Acne'), findsNothing);
        },
      );
    });

    testWidgets('empty timeline state when nothing relevant is logged', (
      tester,
    ) async {
      final db = memoryDb();
      await enablePerimenopause(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openScreen(tester);
          expect(
            find.textContaining('Log perimenopause-related symptoms'),
            findsOneWidget,
          );
          expect(find.byType(CorrelationChart), findsNothing);
        },
      );
    });

    testWidgets('surfaces the 12-month line and the disclaimer', (
      tester,
    ) async {
      final db = memoryDb();
      await enablePerimenopause(db);
      final periods = DriftPeriodRepository(db);
      var start = daysAgo(420 + 28 * 6);
      for (var i = 0; i < 6; i++) {
        await periods.addPeriod(
          PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
        );
        start = start.add(const Duration(days: 28));
      }
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openScreen(tester);
          expect(
            find.textContaining('common definition of menopause'),
            findsWidgets,
          );
          await scrollDown(tester);
          expect(find.text(perimenopauseDisclaimer), findsOneWidget);
        },
      );
    });
  });

  group('copy discipline', () {
    test('the transition read is no numeric score and says so', () {
      // §9(12) hard line: a short honest sentence, never a fake 0–100 / %.
      final numericScore = RegExp(r'\d+\s*(%|/\s*100|out of 100|-\s*100)');
      final blob = <String>[
        perimenopauseExpectedSignalNote,
        perimenopauseTransitionLede,
        perimenopauseTimelineLede,
        perimenopauseTimelineEmpty,
        perimenopauseWiderIntervalNote,
        perimenopauseForecastSuppressedNote,
        perimenopauseSoftenedGapLine,
        perimenopauseDisclaimer,
        for (final h in PerimenopauseStageHint.values)
          perimenopauseStageRead(h),
      ];
      for (final line in blob) {
        final lower = line.toLowerCase();
        expect(line, isNot(matches(numericScore)), reason: line);
        expect(lower, isNot(contains('percent')));
        expect(lower, isNot(contains('p-value')));
        expect(lower, isNot(contains('statistically')));
        expect(lower, isNot(contains('you likely have')));
        expect(lower, isNot(contains('you may have')));
        expect(lower, isNot(contains('ask your doctor about')));
      }
      // …and the read is explicit that it is not a score / not a diagnosis.
      expect(
        perimenopauseTransitionLede.toLowerCase(),
        allOf(contains('not a score'), contains('not a diagnosis')),
      );
    });
  });

  group('cycle-UI reframing on the calendar', () {
    Future<void> seedGapHistory(AppDatabase db) async {
      final periods = DriftPeriodRepository(db);
      for (final ago in const [6, 34, 62, 160]) {
        await periods.addPeriod(
          PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
        );
      }
    }

    testWidgets('mode on: gap wording softens to the transition framing', (
      tester,
    ) async {
      final db = memoryDb();
      await seedGapHistory(db);
      await enablePerimenopause(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // r3b: the gap line is on the cycle-stats card, now on Patterns.
          await switchTab(tester, 'Patterns');
          expect(find.textContaining('perimenopause transition'), findsWidgets);
          expect(
            find.textContaining('a period may not have been logged'),
            findsNothing,
          );
        },
      );
    });

    testWidgets('mode on with a long absence: the forecast is paused', (
      tester,
    ) async {
      final db = memoryDb();
      final periods = DriftPeriodRepository(db);
      var start = daysAgo(400 + 28 * 6);
      for (var i = 0; i < 6; i++) {
        await periods.addPeriod(
          PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
        );
        start = start.add(const Duration(days: 28));
      }
      await enablePerimenopause(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(
            find.text(perimenopauseForecastSuppressedNote),
            findsOneWidget,
          );
          expect(
            find.textContaining('Fertile window (estimate)'),
            findsNothing,
          );
        },
      );
    });

    testWidgets('mode off: the default gap wording stands', (tester) async {
      final db = memoryDb();
      await seedGapHistory(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // r3b: the gap line is on the cycle-stats card, now on Patterns.
          await switchTab(tester, 'Patterns');
          expect(
            find.textContaining('a period may not have been logged'),
            findsWidgets,
          );
          expect(find.textContaining('perimenopause transition'), findsNothing);
        },
      );
    });
  });
}
