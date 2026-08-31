import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// Per-estimator unit tests for [AdaptivePredictor] (p3.2). The backtest suites
/// (`v2_vs_v1_test`, `correction_response_test`) cover aggregate accuracy; this
/// file pins the individual moving parts and the edge cases.
void main() {
  const predictor = AdaptivePredictor();
  final anchorDay = DateTime(2025, 1, 1);

  /// Newest-first cycle history from start-to-start gaps (days).
  List<Cycle> history(List<int> gaps) {
    var day = anchorDay;
    final starts = <DateTime>[day];
    for (final g in gaps) {
      day = day.add(Duration(days: g));
      starts.add(day);
    }
    return cyclesFromStarts(starts);
  }

  CyclePrediction? predictFrom(List<int> gaps) {
    final cycles = history(gaps);
    final today = cycles.first.periodStart.add(const Duration(days: 1));
    return predictor.predict(cycles: cycles, today: today);
  }

  /// Whole days from the anchor (last logged start) to the expected next start.
  int offset(List<int> gaps, CyclePrediction p) {
    final anchor = anchorDay.add(
      Duration(days: gaps.fold<int>(0, (a, b) => a + b)),
    );
    return daysBetween(anchor, p.nextPeriodExpected);
  }

  group('degenerate histories', () {
    test('no cycles → null', () {
      expect(predictor.predict(cycles: const [], today: anchorDay), isNull);
    });

    test('only the open cycle → null', () {
      expect(predictFrom([]), isNull);
    });

    test('history that is all missed-log gaps → null (nothing usable)', () {
      expect(predictFrom([90, 92, 88, 91]), isNull);
    });

    test('open cycle covers a pregnancy end → null', () {
      final cycles = [
        Cycle(
          periodStart: DateTime(2025, 6, 1),
          interruptedBy: PregnancyEndKind.birth,
        ),
        Cycle(
          periodStart: DateTime(2025, 5, 1),
          nextPeriodStart: DateTime(2025, 6, 1),
        ),
        Cycle(
          periodStart: DateTime(2025, 4, 3),
          nextPeriodStart: DateTime(2025, 5, 1),
        ),
      ];
      expect(
        predictor.predict(cycles: cycles, today: DateTime(2025, 6, 10)),
        isNull,
      );
    });
  });

  group('thin history', () {
    test('one completed cycle → humble, low confidence, prior-pulled', () {
      final p = predictFrom([26])!;
      expect(p.basedOnCycles, 1);
      expect(p.confidence, PredictionConfidence.low);
      // Blended toward the 29-day prior: between the observed 26 and 29.
      expect(offset([26], p), inInclusiveRange(26, 29));
      expect(p.nextPeriod.lengthInDays, greaterThanOrEqualTo(2));
    });

    test('two cycles a long way apart → a wide, honest range', () {
      final p = predictFrom([24, 40])!;
      expect(p.confidence, PredictionConfidence.low);
      expect(p.nextPeriod.lengthInDays, greaterThan(6));
    });
  });

  group('regular history', () {
    test('steady 28-day cycles → expected ≈ anchor + 28, tight range', () {
      final gaps = List.filled(10, 28);
      final p = predictFrom(gaps)!;
      expect(offset(gaps, p), inInclusiveRange(27, 29));
      expect(p.nextPeriod.lengthInDays, lessThanOrEqualTo(7));
      expect(
        p.confidence,
        anyOf(PredictionConfidence.medium, PredictionConfidence.high),
      );
    });
  });

  test(
    'recency weighting — a steadier recent run is not dragged by old cycles',
    () {
      // Four old 24-day cycles, five recent 30-day cycles, no monotone trend.
      final gaps = [24, 24, 24, 24, 30, 30, 30, 30, 30];
      final p = predictFrom(gaps)!;
      expect(offset(gaps, p), greaterThanOrEqualTo(29));
    },
  );

  test(
    'skew nudge — a right-skewed history pulls the centre below the mean',
    () {
      // Bulk 27s with a couple of 39s: mean ~30, typical cycle ~27.
      final gaps = [27, 27, 27, 27, 27, 27, 39, 39];
      final p = predictFrom(gaps)!;
      expect(offset(gaps, p), lessThanOrEqualTo(29));
    },
  );

  group('drift', () {
    test('a monotone rising history projects the trend forward', () {
      final gaps = [25, 26, 27, 28, 30, 31, 32, 34, 35, 36];
      final p = predictFrom(gaps)!;
      // Past the most recent length (36) — a trailing median would undershoot.
      expect(offset(gaps, p), greaterThanOrEqualTo(35));
    });

    test('a non-monotone (V-shaped) history does not pick up a slope', () {
      final gaps = [34, 32, 30, 28, 26, 26, 28, 30, 32, 34];
      final p = predictFrom(gaps)!;
      expect(offset(gaps, p), inInclusiveRange(27, 33));
    });
  });

  test('lag-1 outlier gate — a lone recent spike is not chased', () {
    // Steady 29s, then one 44-day cycle (an outlier, but under the 45-day
    // plausibility ramp). The forecast must not jump toward it.
    final gaps = [29, 29, 29, 29, 29, 29, 29, 29, 44];
    final p = predictFrom(gaps)!;
    expect(offset(gaps, p), lessThanOrEqualTo(33));
  });

  group('plausibility down-weight', () {
    test('one very long cycle mid-history barely moves the estimate', () {
      final gapsGap = [28, 28, 28, 70, 28, 28, 28, 28];
      final gapsClean = [28, 28, 28, 28, 28, 28, 28, 28];
      final withGap = predictFrom(gapsGap)!;
      final clean = predictFrom(gapsClean)!;
      expect(
        (offset(gapsGap, withGap) - offset(gapsClean, clean)).abs(),
        lessThanOrEqualTo(2),
      );
      // The range is not blown out by the 70-day cycle.
      expect(withGap.nextPeriod.lengthInDays, lessThanOrEqualTo(10));
    });

    test(
      'no hard cliff — a 45- vs 47-day cycle shift the estimate ≤ 2 days',
      () {
        final g45 = [29, 29, 29, 29, 29, 45, 29, 29];
        final g47 = [29, 29, 29, 29, 29, 47, 29, 29];
        final at45 = predictFrom(g45)!;
        final at47 = predictFrom(g47)!;
        expect(
          (offset(g45, at45) - offset(g47, at47)).abs(),
          lessThanOrEqualTo(2),
        );
      },
    );
  });

  test('pregnancy gap partway through — only the post-gap run is used', () {
    final cycles = [
      Cycle(periodStart: DateTime(2025, 9, 5)), // open
      Cycle(
        periodStart: DateTime(2025, 8, 8),
        nextPeriodStart: DateTime(2025, 9, 5),
      ),
      Cycle(
        periodStart: DateTime(2025, 7, 11),
        nextPeriodStart: DateTime(2025, 8, 8),
      ),
      Cycle(
        periodStart: DateTime(2025, 6, 13),
        nextPeriodStart: DateTime(2025, 7, 11),
      ),
      Cycle(
        periodStart: DateTime(2024, 10, 1),
        nextPeriodStart: DateTime(2025, 6, 13),
        interruptedBy: PregnancyEndKind.birth,
      ),
      Cycle(
        periodStart: DateTime(2024, 9, 3),
        nextPeriodStart: DateTime(2024, 10, 1),
      ),
    ];
    final p = predictor.predict(cycles: cycles, today: DateTime(2025, 9, 6))!;
    // Post-gap cycles are 28, 28, 27 → expected ≈ anchor + 28.
    expect(
      daysBetween(DateTime(2025, 9, 5), p.nextPeriodExpected),
      inInclusiveRange(26, 30),
    );
    expect(p.basedOnCycles, 3);
  });

  group('p3.4 — anti-snowball hardening', () {
    test('a late period never rolls the expected date forward on its own', () {
      // Steady 28-day history; ask long after the expected date with no new
      // period logged. The estimate must stay anchored (v1 behaviour).
      final gaps = List.filled(10, 28);
      final cycles = history(gaps);
      final anchor = cycles.first.periodStart;
      final upcoming = predictor.predict(
        cycles: cycles,
        today: anchor.add(const Duration(days: 1)),
      )!;

      final overdue = predictor.predict(
        cycles: cycles,
        today: anchor.add(const Duration(days: 80)),
      )!;

      expect(overdue.status, PredictionStatus.overdue);
      expect(overdue.isOverdue, isTrue);
      // Same expected date and range as when it was still upcoming — not
      // advanced by a notional extra cycle.
      expect(overdue.nextPeriodExpected, upcoming.nextPeriodExpected);
      expect(overdue.nextPeriod.start, upcoming.nextPeriod.start);
      expect(overdue.nextPeriod.end, upcoming.nextPeriod.end);
      expect(
        overdue.daysPastExpected,
        daysBetween(
          overdue.nextPeriodExpected,
          anchor.add(const Duration(days: 80)),
        ),
      );
    });

    test('a skipped / anovulatory cycle is excluded, not down-weighted', () {
      // One 78-day interval mid-history (a missed log or an anovulatory
      // stretch). Its *value* must not reach any estimator: swapping it for a
      // 120-day interval changes nothing, and the forecast matches the clean
      // history within the loss of the single real cycle it displaced.
      final clean = [28, 28, 27, 28, 29, 28, 28, 27, 28];
      final skip78 = [...clean]..[4] = 78;
      final skip120 = [...clean]..[4] = 120;

      final p78 = predictFrom(skip78)!;
      final p120 = predictFrom(skip120)!;
      final pClean = predictFrom(clean)!;

      // Excluded ⇒ its length is irrelevant.
      expect(offset(skip78, p78), offset(skip120, p120));
      expect(p78.nextPeriod.lengthInDays, p120.nextPeriod.lengthInDays);
      // And it has not dragged the centre or blown out the range.
      expect(
        (offset(skip78, p78) - offset(clean, pClean)).abs(),
        lessThanOrEqualTo(2),
      );
      expect(p78.nextPeriod.lengthInDays, lessThanOrEqualTo(7));
    });

    test(
      'excluding a mid-history skip does not bias a rising trend downward',
      () {
        // A clean rising history vs the same history with one skipped cycle
        // spliced in. The skip is excluded, but the real cycles behind it keep
        // their place on the timeline, so the projected trend is unchanged.
        final rising = [25, 26, 27, 28, 29, 30, 31, 32, 33, 34];
        final withSkip = [25, 26, 27, 28, 90, 29, 30, 31, 32, 33, 34];

        final pRising = predictFrom(rising)!;
        final pSkip = predictFrom(withSkip)!;

        expect(
          (offset(withSkip, pSkip) - offset(rising, pRising)).abs(),
          lessThanOrEqualTo(2),
          reason: 'a skip must not pull a rising projection down',
        );
      },
    );

    test('the AR outlier gate is a ramp, not a cliff', () {
      // Steady 29s, then a moderately long last cycle. The engine may lean a
      // little toward it; a nearly-2-MAD deviation must be chased *less* than a
      // ~1-MAD one — no step change at the old hard gate.
      final base = List.filled(8, 29);
      final nearMad = predictFrom([...base, 33])!; // ~1 MAD-ish over
      final farMad = predictFrom([...base, 40])!; // near the 2-MAD gate

      final leanNear = offset([...base, 33], nearMad) - 29;
      final leanFar = offset([...base, 40], farMad) - 29;

      expect(leanNear, greaterThanOrEqualTo(0));
      expect(
        leanFar,
        lessThanOrEqualTo(leanNear + 1),
        reason: 'the larger deviation must not be chased harder',
      );
    });
  });

  test('deterministic — a pure function of (cycles, today)', () {
    final cycles = history(List.filled(8, 28));
    final today = cycles.first.periodStart.add(const Duration(days: 1));
    expect(
      predictor.predict(cycles: cycles, today: today),
      predictor.predict(cycles: cycles, today: today),
    );
  });
}
