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
/// Redacted surfaces exercised here: the Calendar day cell, the home "Recent
/// activity" rows (r3a — these replaced the old summary flow chip + recent-
/// symptoms list), and the day-log sheet's symptom chips. (Also redacted in
/// `lib/`: the prediction card and the correction notice — see the p5.3 build
/// notes.)
void main() {
  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<AppDatabase> seeded() async {
    final db = memoryDb();
    // An ongoing period plus a flow + a symptom on different days so the home
    // "Recent activity" list has a row to speak / redact.
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
        // Home "Recent activity" rows speak the specifics.
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('1 symptom')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('has entries')), findsNothing);

        // The Calendar day cell speaks the flow intensity too.
        await switchTab(tester, 'Calendar');
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsWidgets);
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
        // Home "Recent activity": each row announces only "<date>, has
        // entries" …
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsNothing);
        expect(find.bySemanticsLabel(RegExp('1 symptom')), findsNothing);
        expect(
          find.bySemanticsLabel('${formatDay(today)}, has entries'),
          findsOneWidget,
        );
        // … while the visible detail text is untouched.
        expect(find.text('flow heavy'), findsWidgets);
        expect(find.text('1 symptom'), findsWidgets);

        // The Calendar day cell redacts the same way.
        await switchTab(tester, 'Calendar');
        expect(find.bySemanticsLabel(RegExp('flow heavy')), findsNothing);
        expect(
          find.bySemanticsLabel('${formatDay(today)}, has entries'),
          findsWidgets,
        );
      },
    );
  });

  testWidgets('reduce ON: day-log sheet symptom chips announce "symptom"', (
    tester,
  ) async {
    final db = memoryDb();
    // The "Log" FAB opens the unified day-log sheet; today leads with Flow, so
    // expand the Symptoms section to reach its chips.
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        reduceSpokenDetailProvider.overrideWith((ref) => Stream.value(true)),
      ],
      body: () async {
        await openDayLogForToday(tester);

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
