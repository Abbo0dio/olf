import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/correlation_chart.dart';
import 'package:olf_app/src/modes/endometriosis_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> enableEndo(AppDatabase db) => DriftSettingsRepository(
    db,
  ).set(LifeStageMode.endometriosis.settingKey, 'true');

  Future<void> openEndoScreen(WidgetTester tester) async {
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
      find.text('Open Endometriosis'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open Endometriosis'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Endometriosis'), findsOneWidget);
  }

  /// Four periods 28 days apart (three completed cycles + the open one) with
  /// flares logged only on luteal-phase days across them.
  Future<void> seedFlares(AppDatabase db) async {
    await enableEndo(db);
    final periods = DriftPeriodRepository(db);
    for (final ago in const [112, 84, 56, 28]) {
      await periods.addPeriod(
        PeriodDraft(start: daysAgo(ago), end: daysAgo(ago - 3)),
      );
    }
    final pain = DriftPainRepository(db);
    for (final ago in const [95, 93, 91, 67, 65, 63, 39, 37, 35]) {
      await pain.setPain(
        daysAgo(ago),
        intensity: SymptomSeverity.moderate,
        region: PainRegion.pelvic,
        isFlare: true,
      );
    }
  }

  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
    await tester.pumpAndSettle();
  }

  group('Endometriosis screen', () {
    testWidgets(
      'renders the flare correlation with a chart and a named phase',
      (tester) async {
        final db = memoryDb();
        await seedFlares(db);
        await pumpOlf(
          tester,
          overrides: [dbOverride(db)],
          body: () async {
            await openEndoScreen(tester);
            expect(find.text('Flares'), findsOneWidget);
            expect(find.byType(CorrelationChart), findsWidgets);
            expect(
              find.textContaining('most often in your luteal phase'),
              findsWidgets,
            );
          },
        );
      },
    );

    testWidgets('shows an empty state when nothing is logged', (tester) async {
      final db = memoryDb();
      await enableEndo(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openEndoScreen(tester);
          expect(find.text(endoEmptyState), findsOneWidget);
          expect(find.byType(CorrelationChart), findsNothing);
        },
      );
    });

    testWidgets('carries the disclaimer and the not-a-diagnosis line', (
      tester,
    ) async {
      final db = memoryDb();
      await seedFlares(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openEndoScreen(tester);
          expect(find.text(endoNotDiagnosisLine), findsOneWidget);
          await scrollToBottom(tester);
          expect(find.text(endoDisclaimer), findsOneWidget);
        },
      );
    });

    testWidgets('logs a pain day through the repository and shows it', (
      tester,
    ) async {
      final db = memoryDb();
      await enableEndo(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await openEndoScreen(tester);
          await tester.tap(find.text("Log today's pain"));
          await tester.pumpAndSettle();

          await tester.tap(find.widgetWithText(ChoiceChip, 'Moderate'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ChoiceChip, 'Pelvic'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('This is a flare'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          // Written through the real repository.
          final row = await DriftPainRepository(
            db,
          ).painOn(DateTime(today.year, today.month, today.day));
          expect(row, isNotNull);
          expect(row!.intensity, SymptomSeverity.moderate);
          expect(row.region, PainRegion.pelvic);
          expect(row.isFlare, isTrue);

          // And surfaced back on the screen.
          expect(find.textContaining('Today: Moderate'), findsOneWidget);
        },
      );
    });
  });

  group('copy discipline', () {
    test('mode copy carries no verdict or directive language', () {
      const blob = [
        endoIntro,
        endoAcrossCycleHeading,
        endoNotDiagnosisLine,
        endoEmptyState,
        endoDisclaimer,
      ];
      for (final line in blob) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('ask your doctor about')));
        expect(lower, isNot(contains('you likely have')));
        expect(lower, isNot(contains('you may have')));
        expect(lower, isNot(contains('p-value')));
        expect(lower, isNot(contains('statistically')));
      }
    });
  });
}
