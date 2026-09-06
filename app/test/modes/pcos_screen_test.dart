import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/correlation_chart.dart';
import 'package:olf_app/src/modes/pcos_correlation_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> enablePcos(AppDatabase db) =>
      DriftSettingsRepository(db).set(LifeStageMode.pcos.settingKey, 'true');

  Future<void> openPcosScreen(WidgetTester tester) async {
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
      find.text('Open PCOS'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open PCOS'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'PCOS'), findsOneWidget);
  }

  Future<SymptomType> builtInType(AppDatabase db, String name) async {
    final types = await DriftSymptomRepository(db).activeTypes();
    return types.firstWhere((t) => t.name == name);
  }

  /// Four periods 28 days apart (three completed cycles + the open one) with
  /// "Cramps" logged only on luteal-phase days across them.
  Future<void> seedCorrelation(AppDatabase db) async {
    await enablePcos(db);
    final periods = DriftPeriodRepository(db);
    for (final ago in const [112, 84, 56, 28]) {
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
      );
    }
    final symptoms = DriftSymptomRepository(db);
    final cramps = await builtInType(db, 'Cramps');
    for (final ago in const [90, 88, 86, 62, 60, 58, 34, 32, 30]) {
      await symptoms.setSymptom(daysAgo(ago), cramps.id, present: true);
    }
  }

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
  }

  group('PCOS screen', () {
    testWidgets('renders the correlation view with a chart and a named phase', (
      tester,
    ) async {
      final db = memoryDb();
      await seedCorrelation(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPcosScreen(tester);
          expect(find.text('Cramps'), findsOneWidget);
          expect(find.byType(CorrelationChart), findsOneWidget);
          expect(
            find.textContaining('most often in your luteal phase'),
            findsOneWidget,
          );
        },
      );
    });

    testWidgets('shows an empty state when nothing is logged', (tester) async {
      final db = memoryDb();
      await enablePcos(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPcosScreen(tester);
          expect(
            find.textContaining('Log symptoms over a few cycles'),
            findsOneWidget,
          );
          expect(find.byType(CorrelationChart), findsNothing);
        },
      );
    });

    testWidgets('a symptom with too little history reads "not enough data"', (
      tester,
    ) async {
      final db = memoryDb();
      await enablePcos(db);
      final cramps = await builtInType(db, 'Cramps');
      await DriftSymptomRepository(
        db,
      ).setSymptom(daysAgo(2), cramps.id, present: true);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openPcosScreen(tester);
          expect(find.text('Cramps'), findsOneWidget);
          expect(
            find.textContaining('Not enough logged days yet'),
            findsOneWidget,
          );
          expect(find.byType(CorrelationChart), findsNothing);
        },
      );
    });

    testWidgets(
      'carries the disclaimer and is explicitly not a symptom check',
      (tester) async {
        final db = memoryDb();
        await seedCorrelation(db);
        await pumpOlf(
          tester,
          overrides: [dbOverride(db)],
          body: () async {
            await openPcosScreen(tester);
            expect(find.text(pcosNotSymptomCheckerLine), findsOneWidget);
            // Never the Flo "ask your doctor about PCOS" anti-pattern.
            expect(find.textContaining('ask your doctor about'), findsNothing);

            await scrollToBottom(tester);
            expect(find.text(pcosDisclaimer), findsOneWidget);
          },
        );
      },
    );
  });

  group('copy discipline', () {
    test('mode copy carries no verdict or directive language', () {
      const blob = [
        pcosIrregularCycleNote,
        pcosWiderIntervalNote,
        pcosSoftenedGapLine,
        pcosNotSymptomCheckerLine,
        pcosDisclaimer,
      ];
      for (final line in blob) {
        final lower = line.toLowerCase();
        // No directive ("ask your doctor about PCOS", the Flo anti-pattern) …
        expect(lower, isNot(contains('ask your doctor about')));
        // … and no positive verdict.
        expect(lower, isNot(contains('you likely have')));
        expect(lower, isNot(contains('you may have')));
        expect(lower, isNot(contains('p-value')));
        expect(lower, isNot(contains('statistically')));
      }
    });
  });

  group('cycle-UI softening on the calendar', () {
    Future<void> seedGapHistory(AppDatabase db) async {
      final periods = DriftPeriodRepository(db);
      for (final ago in const [6, 34, 62, 160]) {
        await periods.addPeriod(
          PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
        );
      }
    }

    testWidgets('PCOS mode on: gap wording softens and a wider-interval note '
        'appears', (tester) async {
      final db = memoryDb();
      await seedGapHistory(db);
      await enablePcos(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.textContaining('common with PCOS'), findsWidgets);
          expect(
            find.textContaining('a period may not have been logged'),
            findsNothing,
          );
          expect(
            find.textContaining('treat the date range as wide'),
            findsOneWidget,
          );
        },
      );
    });

    testWidgets('PCOS mode off: the default gap wording stands', (
      tester,
    ) async {
      final db = memoryDb();
      await seedGapHistory(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(
            find.textContaining('a period may not have been logged'),
            findsWidgets,
          );
          expect(find.textContaining('common with PCOS'), findsNothing);
          expect(
            find.textContaining('treat the date range as wide'),
            findsNothing,
          );
        },
      );
    });
  });
}
