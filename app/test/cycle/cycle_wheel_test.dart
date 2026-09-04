import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/cycle/cycle_wheel.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

/// p1.12 — the cycle-phase wheel is a pure presentation over `core`'s
/// `currentCyclePhase`: this test builds real [CyclePhase] fixtures (via that
/// function, not by hand) for each of the four phases plus the no-anchor
/// `null` state, and checks rendering, the tap-to-correct affordance, and
/// "Reduce spoken detail" (p5.3) redaction.
void main() {
  final periodStart = DateTime(2026, 1, 1);
  final periodEnd = DateTime(2026, 1, 5);
  final fertileWindow = DateRange(DateTime(2026, 1, 12), DateTime(2026, 1, 16));
  final nextPeriodExpected = DateTime(2026, 1, 28);

  final cycle = Cycle(periodStart: periodStart, periodEnd: periodEnd);
  final prediction = CyclePrediction(
    nextPeriod: DateRange(
      addDays(nextPeriodExpected, -2),
      addDays(nextPeriodExpected, 2),
    ),
    nextPeriodExpected: nextPeriodExpected,
    fertileWindow: fertileWindow,
    confidence: PredictionConfidence.medium,
    basedOnCycles: 6,
    status: PredictionStatus.upcoming,
    daysPastExpected: null,
  );

  CyclePhase phaseOn(DateTime today) =>
      currentCyclePhase(cycle: cycle, prediction: prediction, today: today)!;

  Widget host({
    required CyclePhase? phase,
    bool reduceSpoken = false,
    VoidCallback? onTap,
  }) => MaterialApp(
    theme: olfTheme(Brightness.light),
    home: Scaffold(
      body: Center(
        child: CycleWheel(
          phase: phase,
          reduceSpoken: reduceSpoken,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );

  for (final entry in {
    CyclePhaseKind.menstrual: periodStart,
    CyclePhaseKind.follicular: addDays(periodEnd, 1),
    CyclePhaseKind.ovulatory: fertileWindow.start,
    CyclePhaseKind.luteal: addDays(fertileWindow.end, 1),
  }.entries) {
    testWidgets('renders the ${entry.key.name} phase', (tester) async {
      final phase = phaseOn(entry.value);
      await tester.pumpWidget(host(phase: phase));

      expect(find.text(entry.key.label), findsOneWidget);
      expect(find.textContaining('Day '), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the no-anchor placeholder never fabricates a phase', (
    tester,
  ) async {
    await tester.pumpWidget(host(phase: null));

    expect(find.text('Log a period to see this'), findsOneWidget);
    for (final kind in CyclePhaseKind.values) {
      expect(find.text(kind.label), findsNothing);
    }
    expect(find.textContaining('Day '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the wheel reaches the same today quick-log action', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      host(phase: phaseOn(periodStart), onTap: () => tapped++),
    );

    // The ring's InkWell, not `find.byType(CycleWheel)` — that finder's
    // render box spans the whole column (ring + caption text below it), so
    // its geometric center can land on the caption rather than the ring.
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('tapping the placeholder still reaches the quick-log action', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(host(phase: null, onTap: () => tapped++));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('reduce OFF (default): the phase and day are spoken', (
    tester,
  ) async {
    await tester.pumpWidget(host(phase: phaseOn(periodStart)));

    // A more specific match than plain "Menstrual" — the caption `Text`
    // widget gets its own implicit semantics too, so a bare "Menstrual"
    // regex would also match that (expected, harmless) node.
    expect(
      find.bySemanticsLabel(RegExp('Currently Menstrual, day 1')),
      findsOneWidget,
    );
  });

  testWidgets('reduce ON: the semantic label redacts, visible text unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(phase: phaseOn(periodStart), reduceSpoken: true),
    );

    expect(find.bySemanticsLabel(RegExp('Currently Menstrual')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Cycle phase available')),
      findsOneWidget,
    );
    // Visible text is untouched by the redaction.
    expect(find.text(CyclePhaseKind.menstrual.label), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
  });

  testWidgets('renders cleanly in dark mode too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: olfTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: CycleWheel(
              phase: phaseOn(fertileWindow.start),
              reduceSpoken: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
