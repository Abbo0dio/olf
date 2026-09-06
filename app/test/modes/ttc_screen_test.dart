import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/ttc_providers.dart';
import 'package:olf_app/src/modes/ttc_screen.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;
  setUp(() => nextId = 1);

  Period period(DateTime start) => Period(
    id: nextId++,
    startDate: start,
    endDate: start.add(const Duration(days: 4)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  BbtEntry temp(DateTime date, double celsius) => BbtEntry(
    date: date,
    tempCelsius: celsius,
    source: 'manual',
    measurementKind: BbtMeasurementKind.basal,
    createdAt: epoch,
    updatedAt: epoch,
  );

  List<Period> regularHistory(DateTime lastStart) => [
    for (var i = 9; i >= 0; i--)
      period(lastStart.subtract(Duration(days: 28 * i))),
  ];

  List<DailyFertilityScore> outlook({
    required DateTime lastPeriod,
    required DateTime today,
    List<BbtEntry> bbt = const [],
  }) {
    final periods = regularHistory(lastPeriod);
    final cycles = deriveCycles(periods);
    return dailyFertilityScores(
      cycles: cycles,
      bbt: bbt,
      mucus: const [],
      prediction: const AdaptivePredictor().predict(
        cycles: cycles,
        today: today,
      ),
      today: today,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    List<DailyFertilityScore> scores,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ttcFertilityOutlookProvider.overrideWithValue(scores)],
        child: MaterialApp(
          theme: olfTheme(Brightness.light),
          home: const TtcScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders the score, the fertile window as a range, and guidance',
    (tester) async {
      final anchor = DateTime(2026, 6, 1);
      await pump(
        tester,
        outlook(lastPeriod: anchor, today: anchor.add(const Duration(days: 8))),
      );

      expect(find.textContaining('/ 100'), findsOneWidget);
      expect(find.textContaining('Fertile window:'), findsOneWidget);
      // A range, never a single day — the line carries an en-dash separator.
      expect(find.textContaining('–'), findsWidgets);
      expect(find.text('Next days'), findsOneWidget);
      expect(find.textContaining("What shaped today's score"), findsOneWidget);
    },
  );

  testWidgets('carries the not-a-medical-device + not-contraception note', (
    tester,
  ) async {
    final anchor = DateTime(2026, 6, 1);
    await pump(
      tester,
      outlook(lastPeriod: anchor, today: anchor.add(const Duration(days: 8))),
    );
    // The disclaimer sits at the foot of a long ListView.
    await tester.scrollUntilVisible(
      find.textContaining('not contraception guidance'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('not a medical device'), findsOneWidget);
    expect(find.textContaining('not contraception guidance'), findsOneWidget);
  });

  testWidgets('honest empty state when there is not enough history', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(find.text('Not enough history yet'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing);
    expect(find.textContaining('Fertile window:'), findsNothing);
    // The disclaimer — including the contraception note — still shows.
    expect(find.textContaining('not contraception guidance'), findsOneWidget);
  });

  testWidgets('a logged thermal shift is visible as a reason the score moved', (
    tester,
  ) async {
    final anchor = DateTime(2026, 6, 1);
    final today = anchor.add(const Duration(days: 13));
    final bbt = <BbtEntry>[
      for (var i = 0; i < 6; i++)
        temp(
          anchor.add(Duration(days: 4 + i)),
          36.40 + (i.isEven ? 0.0 : 0.02),
        ),
      temp(anchor.add(const Duration(days: 10)), 36.70),
      temp(anchor.add(const Duration(days: 11)), 36.72),
      temp(anchor.add(const Duration(days: 12)), 36.69),
    ];

    final scores = outlook(lastPeriod: anchor, today: today, bbt: bbt);
    expect(
      scores.first.factors,
      contains(FertilityFactor.thermalShiftPassed),
      reason: 'fixture should put today past a confirmed shift',
    );

    await pump(tester, scores);
    expect(
      find.textContaining('temperature rise suggests ovulation'),
      findsWidgets,
    );
  });
}
