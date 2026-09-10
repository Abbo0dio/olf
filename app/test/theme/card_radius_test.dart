import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/forecast_area.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// r5a — the home / Patterns cards all go through the theme `Card` (radius 16,
/// elevation 0, neutral `surfaceContainer*`), and the one screen accent stays
/// on the forecast card. This locks in:
///
///  * the theme's card radius is 16 (guards `olf_theme.dart` drift);
///  * no in-scope card is drawn as a hand-rolled `BorderRadius.circular(12)`
///    container any more;
///  * every `Card` on Home and Patterns resolves to radius 16;
///  * the forecast card keeps `primaryContainer`; the overdue check-in does
///    **not** flip the background to `tertiaryContainer` — it is set apart by a
///    leading icon and a thin `error` edge instead;
///  * the recalibration / perimenopause notes are no longer `secondaryContainer`.
///
/// The systematic contrast proof is `theme_contrast_test.dart` (untouched here —
/// no token changed); this is the "the widgets paint the roles the token test
/// assumes" belt-and-braces for the card pass.
void main() {
  BorderRadius? radiusOf(ShapeBorder? shape) {
    if (shape is RoundedRectangleBorder) {
      final r = shape.borderRadius;
      return r is BorderRadius ? r : null;
    }
    return null;
  }

  bool isRadius16(ShapeBorder? shape) =>
      radiusOf(shape) == BorderRadius.circular(16);

  /// Every `Card` in the tree resolves to radius 16 — either explicitly, or by
  /// inheriting the theme (whose radius `theme card radius is 16` pins at 16).
  void expectAllCardsRadius16(WidgetTester tester) {
    final cards = tester.widgetList<Card>(find.byType(Card));
    expect(cards, isNotEmpty);
    for (final card in cards) {
      expect(
        card.shape == null || isRadius16(card.shape),
        isTrue,
        reason: 'a Card is drawn at radius ${radiusOf(card.shape)}, not 16',
      );
    }
  }

  /// No widget in the tree is a hand-rolled `BorderRadius.circular(12)` card.
  void expectNoRadius12(WidgetTester tester) {
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final d = box.decoration;
      if (d is BoxDecoration) {
        expect(
          d.borderRadius,
          isNot(BorderRadius.circular(12)),
          reason: 'a BoxDecoration is still drawn at radius 12',
        );
      }
    }
  }

  Iterable<BoxDecoration> boxDecorations(WidgetTester tester) sync* {
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final d = box.decoration;
      if (d is BoxDecoration) yield d;
    }
  }

  test('theme card radius is 16, both brightnesses', () {
    for (final b in Brightness.values) {
      expect(isRadius16(olfTheme(b).cardTheme.shape), isTrue);
    }
  });

  group('ForecastArea', () {
    final today = DateTime.now();
    DateTime at(int d) =>
        DateTime(today.year, today.month, today.day).add(Duration(days: d));

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

    Future<void> pump(
      WidgetTester tester, {
      CyclePrediction? prediction,
      bool bcRecalActive = false,
      bool perimenopauseGapSuppress = false,
      Brightness brightness = Brightness.light,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: olfTheme(brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForecastArea(
              prediction: prediction,
              bcRecalActive: bcRecalActive,
              perimenopauseGapSuppress: perimenopauseGapSuppress,
              pregnancyModeOn: false,
              reduceSpoken: false,
              onLogPeriodStart: () {},
              onDismissRecalibration: () {},
            ),
          ),
        ),
      ),
    );

    testWidgets('forecast card: one Card, radius 16, keeps primaryContainer', (
      tester,
    ) async {
      await pump(tester, prediction: upcoming());
      final scheme = olfTheme(Brightness.light).colorScheme;

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.shape == null || isRadius16(card.shape), isTrue);
      expect(card.color, scheme.primaryContainer);
      expectNoRadius12(tester);
    });

    testWidgets(
      'overdue check-in: no tertiaryContainer background, leading icon, error edge',
      (tester) async {
        await pump(tester, prediction: overdue());
        final scheme = olfTheme(Brightness.light).colorScheme;

        // The check-in is the branch under test.
        expect(find.text('Period check-in'), findsOneWidget);
        // A leading icon marks it — not colour alone.
        expect(find.byIcon(Icons.event_busy_outlined), findsOneWidget);

        final card = tester.widget<Card>(find.byType(Card));
        // Same surface as the forecast card — no full background flip.
        expect(card.color, scheme.primaryContainer);
        expect(card.color, isNot(scheme.tertiaryContainer));
        // The distinct look is a thin error edge at radius 16.
        final shape = card.shape;
        expect(shape, isA<RoundedRectangleBorder>());
        expect(isRadius16(shape), isTrue);
        expect((shape as RoundedRectangleBorder).side.color, scheme.error);

        // Nothing in the subtree is painted tertiaryContainer or radius 12.
        for (final d in boxDecorations(tester)) {
          expect(d.color, isNot(scheme.tertiaryContainer));
        }
        expectNoRadius12(tester);
      },
    );

    testWidgets('recalibration note: neutral Card, not secondaryContainer', (
      tester,
    ) async {
      await pump(tester, bcRecalActive: true);
      final scheme = olfTheme(Brightness.light).colorScheme;

      expect(find.byType(Card), findsOneWidget);
      expectAllCardsRadius16(tester);
      for (final d in boxDecorations(tester)) {
        expect(d.color, isNot(scheme.secondaryContainer));
      }
      expectNoRadius12(tester);
    });

    testWidgets(
      'perimenopause paused note: neutral Card, not secondaryContainer',
      (tester) async {
        await pump(
          tester,
          prediction: upcoming(),
          perimenopauseGapSuppress: true,
        );
        final scheme = olfTheme(Brightness.light).colorScheme;

        expect(find.byType(Card), findsOneWidget);
        expectAllCardsRadius16(tester);
        for (final d in boxDecorations(tester)) {
          expect(d.color, isNot(scheme.secondaryContainer));
        }
        expectNoRadius12(tester);
      },
    );
  });

  group('on the real tabs', () {
    DateTime daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

    Future<void> seed(AppDatabase db) async {
      final repo = DriftPeriodRepository(db);
      for (final ago in const [132, 104, 76, 48, 20]) {
        final s = daysAgo(ago);
        await repo.addPeriod(
          PeriodDraft(start: s, end: s.add(const Duration(days: 3))),
        );
      }
    }

    testWidgets('Home tab: all Cards radius 16, no radius-12 container', (
      tester,
    ) async {
      final db = memoryDb();
      await seed(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          expect(find.text('Next period'), findsOneWidget);
          expectAllCardsRadius16(tester);
          expectNoRadius12(tester);
        },
      );
    });

    testWidgets('Patterns tab: all Cards radius 16, no radius-12 container', (
      tester,
    ) async {
      final db = memoryDb();
      await seed(db);
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await switchTab(tester, 'Patterns');
          expect(find.text('Your cycles'), findsOneWidget);
          expectAllCardsRadius16(tester);
          expectNoRadius12(tester);
        },
      );
    });
  });
}
