import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/a11y/spoken_detail.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p5.3 — "Reduce spoken detail" swaps sensitive `Semantics` labels for a
/// generic form (an entry *exists*, not what it is). The **visible** text must
/// never change.
///
/// Redacted surfaces exercised here: the calendar day cell, today's flow chip,
/// the recent-symptoms list, and the day-log sheet's symptom chips. (Also redacted
/// in `lib/`: the prediction card and the correction notice — see the p5.3
/// build notes.)
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<AppDatabase> seeded() async {
    final db = memoryDb();
    // An ongoing period so the summary shows today's flow chip.
    await DriftPeriodRepository(db).addPeriod(PeriodDraft(start: daysAgo(2)));
    await DriftDailyFlowRepository(
      db,
    ).setFlow(today, intensity: FlowIntensity.heavy);
    final symptoms = DriftSymptomRepository(db);
    final headache = (await symptoms.activeTypes())
        .firstWhere((t) => t.name == 'Headache')
        .id;
    await symptoms.setSymptom(daysAgo(1), headache, present: true);
    return db;
  }

  testWidgets('reduce OFF (default): full detail is spoken', (tester) async {
    final db = await seeded();
    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        // Day cell speaks the flow intensity.
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsWidgets);
        // Recent-symptoms line speaks the symptom name.
        expect(find.bySemanticsLabel(RegExp('Headache')), findsWidgets);
        // No redacted phrasing anywhere.
        expect(find.bySemanticsLabel(RegExp('has entries')), findsNothing);
      },
    );
  });

  testWidgets('reduce ON: sensitive labels redact, visible text unchanged', (
    tester,
  ) async {
    final db = await seeded();
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reduceSpokenDetailProvider.overrideWith((ref) => Stream.value(true)),
      ],
      body: () async {
        // Day cell: "<date>, has entries" instead of the flow intensity.
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp('^${RegExp.escape(formatDay(today))}, has entries\$'),
          ),
          findsOneWidget,
        );

        // Recent-symptoms line: "1 symptom" instead of "Headache" — but the
        // visible text is still the name.
        expect(find.bySemanticsLabel(RegExp('^Headache\$')), findsNothing);
        expect(find.text('Headache'), findsWidgets);

        // Today's flow chip: redacted announcement, visible label unchanged.
        expect(find.bySemanticsLabel("Today's flow logged"), findsOneWidget);
        expect(find.text("Today's flow: Heavy"), findsOneWidget);
      },
    );
  });

  testWidgets('reduce ON: day-log sheet symptom chips announce "symptom"', (
    tester,
  ) async {
    final db = memoryDb();
    // Tapping today opens the unified day-log sheet; today leads with Flow, so
    // expand the Symptoms section to reach its chips.
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reduceSpokenDetailProvider.overrideWith((ref) => Stream.value(true)),
      ],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(
            RegExp('^${RegExp.escape(formatDay(today))}\$'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Day log — ${formatDay(today)}'), findsOneWidget);
        await tester.tap(find.text('Symptoms'));
        await tester.pumpAndSettle();
        // The chip's visible label is the real name…
        expect(find.widgetWithText(FilterChip, 'Headache'), findsOneWidget);
        // …but a screen reader hears the generic word.
        expect(find.bySemanticsLabel('symptom'), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('^Headache\$')), findsNothing);
      },
    );
  });
}
