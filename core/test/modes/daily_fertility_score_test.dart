import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

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

  BbtEntry temp(
    DateTime date,
    double celsius, {
    BbtMeasurementKind kind = BbtMeasurementKind.basal,
  }) => BbtEntry(
    date: date,
    tempCelsius: celsius,
    source: 'manual',
    measurementKind: kind,
    createdAt: epoch,
    updatedAt: epoch,
  );

  CervicalMucusEntry mucus(DateTime date, CervicalMucusType type) =>
      CervicalMucusEntry(
        date: date,
        type: type,
        createdAt: epoch,
        updatedAt: epoch,
      );

  /// [count] periods [gap] days apart, the most recent starting [lastStart].
  List<Period> regularHistory(
    DateTime lastStart, {
    int gap = 28,
    int count = 10,
  }) => [
    for (var i = count - 1; i >= 0; i--)
      period(lastStart.subtract(Duration(days: gap * i))),
  ];

  List<Period> historyWithLengths(DateTime lastStart, List<int> gaps) {
    final starts = <DateTime>[lastStart];
    for (final g in gaps) {
      starts.add(starts.last.subtract(Duration(days: g)));
    }
    return [for (final s in starts.reversed) period(s)];
  }

  CyclePrediction? predict(List<Period> periods, DateTime today) =>
      const AdaptivePredictor().predict(
        cycles: deriveCycles(periods),
        today: today,
      );

  DailyFertilityScore? score(
    List<Period> periods, {
    required DateTime today,
    required DateTime day,
    List<BbtEntry> bbt = const [],
    List<CervicalMucusEntry> mucus = const [],
  }) {
    final cycles = deriveCycles(periods);
    return dailyFertilityScore(
      cycles: cycles,
      bbt: bbt,
      mucus: mucus,
      prediction: predict(periods, today),
      today: today,
      day: day,
    );
  }

  group('thin history → no score (honest empty state)', () {
    test('a single completed cycle returns null', () {
      final anchor = DateTime(2026, 6, 1);
      final periods = [
        period(anchor.subtract(const Duration(days: 28))),
        period(anchor),
      ];
      expect(
        score(periods, today: anchor.add(const Duration(days: 8)), day: anchor),
        isNull,
      );
    });

    test('the series is empty when there is no usable prediction', () {
      final anchor = DateTime(2026, 6, 1);
      final periods = [period(anchor)];
      expect(
        dailyFertilityScores(
          cycles: deriveCycles(periods),
          bbt: const [],
          mucus: const [],
          prediction: predict(periods, anchor.add(const Duration(days: 5))),
          today: anchor.add(const Duration(days: 5)),
        ),
        isEmpty,
      );
    });
  });

  group('a clear fertile window', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = regularHistory(anchor);
    final today = anchor.add(const Duration(days: 8));

    List<DailyFertilityScore> series() => dailyFertilityScores(
      cycles: deriveCycles(periods),
      bbt: const [],
      mucus: const [],
      prediction: predict(periods, today),
      today: today,
      days: 8,
    );

    test('score is elevated across the window with one clear peak', () {
      final s = series();
      expect(s, hasLength(8));

      final peak = s.reduce((a, b) => a.score >= b.score ? a : b);
      // Exactly one day holds the maximum.
      expect(s.where((d) => d.score == peak.score), hasLength(1));
      expect(peak.isPeak, isTrue);
      expect(peak.date, peak.peakDay);
      // A regular 28-day history places ovulation ~14 days after the anchor.
      expect(peak.date, anchor.add(const Duration(days: 14)));

      // The three days up to and including the peak all read as elevated…
      for (final offset in const [12, 13, 14]) {
        final d = s.firstWhere(
          (e) => e.date == anchor.add(Duration(days: offset)),
        );
        expect(d.score, greaterThan(40), reason: 'day +$offset');
      }
      // …and a day well before the run-up does not.
      final early = s.first; // today = anchor + 8
      expect(early.score, lessThan(20));
    });

    test('the fertile window is a multi-day range, never one day', () {
      final peak = series().reduce((a, b) => a.score >= b.score ? a : b);
      expect(peak.fertileWindow.lengthInDays, greaterThan(1));
      expect(peak.fertileWindow.contains(peak.peakDay), isTrue);
    });

    test('a regular, deep history reads as high confidence', () {
      final peak = series().reduce((a, b) => a.score >= b.score ? a : b);
      expect(peak.confidence, FertilityConfidence.high);
      expect(peak.high - peak.low, lessThanOrEqualTo(12));
      expect(peak.factors, contains(FertilityFactor.predictedWindow));
    });
  });

  test('a logged thermal shift moves the peak earlier and closes the window', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = regularHistory(anchor);
    // Ovulation predicted ~anchor+14; a thermal shift confirms it at anchor+9.
    final shiftDays = <BbtEntry>[
      for (var i = 0; i < 6; i++)
        temp(
          anchor.add(Duration(days: 4 + i)),
          36.40 + (i.isEven ? 0.0 : 0.02),
        ),
      temp(anchor.add(const Duration(days: 10)), 36.70),
      temp(anchor.add(const Duration(days: 11)), 36.72),
      temp(anchor.add(const Duration(days: 12)), 36.69),
    ];
    final today = anchor.add(const Duration(days: 13));

    final withoutShift = score(
      periods,
      today: today,
      day: anchor.add(const Duration(days: 14)),
    )!;
    expect(withoutShift.peakDay, anchor.add(const Duration(days: 14)));

    final withShift = score(periods, today: today, day: today, bbt: shiftDays)!;
    // Peak re-centred onto the confirmed ovulation (shift day − 1 = anchor+9).
    expect(withShift.peakDay, anchor.add(const Duration(days: 9)));
    // `today` is well past that now → the window has closed.
    expect(withShift.score, lessThan(10));
    expect(withShift.factors, contains(FertilityFactor.thermalShiftPassed));
    // An observed signal firms the read up.
    expect(withShift.confidence, isNot(FertilityConfidence.low));
  });

  // p8.1a: `dailyFertilityScore` reads BBT only through `thermalShift`, which
  // ignores `sleepingWrist` rows. A passive Apple Watch reading interleaved
  // with the basal history must not move the score, the peak, or the factors.
  test('sleepingWrist readings do not affect the fertility score', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = regularHistory(anchor);
    List<BbtEntry> basalShift() => [
      for (var i = 0; i < 6; i++)
        temp(
          anchor.add(Duration(days: 4 + i)),
          36.40 + (i.isEven ? 0.0 : 0.02),
        ),
      temp(anchor.add(const Duration(days: 10)), 36.70),
      temp(anchor.add(const Duration(days: 11)), 36.72),
      temp(anchor.add(const Duration(days: 12)), 36.69),
    ];
    // Wrist readings that would obliterate the shift if they counted.
    final wristNoise = [
      temp(
        anchor.add(const Duration(days: 5)),
        38.6,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
      temp(
        anchor.add(const Duration(days: 10)),
        35.0,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
      temp(
        anchor.add(const Duration(days: 12)),
        34.8,
        kind: BbtMeasurementKind.sleepingWrist,
      ),
    ];
    final today = anchor.add(const Duration(days: 13));

    final basalOnly = score(
      periods,
      today: today,
      day: today,
      bbt: basalShift(),
    )!;
    final mixed = score(
      periods,
      today: today,
      day: today,
      bbt: [...basalShift(), ...wristNoise],
    )!;

    expect(mixed.peakDay, basalOnly.peakDay);
    expect(mixed.score, basalOnly.score);
    expect(mixed.confidence, basalOnly.confidence);
    expect(mixed.factors, basalOnly.factors);
  });

  test('an irregular history stays humble even on its best day', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = historyWithLengths(anchor, const [
      24,
      41,
      27,
      45,
      22,
      38,
      26,
      43,
      30,
      21,
      40,
    ]);
    final today = anchor.add(const Duration(days: 6));
    final prediction = predict(periods, today);
    expect(prediction, isNotNull, reason: 'needs a prediction to score at all');

    final cycles = deriveCycles(periods);
    expect(CycleStats.from(cycles).regularity, CycleRegularity.irregular);

    DailyFertilityScore? best;
    for (var i = 0; i < 20; i++) {
      final s = dailyFertilityScore(
        cycles: cycles,
        bbt: const [],
        mucus: const [],
        prediction: prediction,
        today: today,
        day: anchor.add(Duration(days: i)),
      )!;
      expect(s.confidence, FertilityConfidence.low);
      if (best == null || s.score > best.score) best = s;
    }
    // Shrunk toward the humble baseline — no fake "you're 95% fertile today" —
    // and the band around even the best day stays wide.
    expect(best!.score, lessThan(60));
    expect(best.high - best.low, greaterThanOrEqualTo(40));
    expect(best.factors, contains(FertilityFactor.irregularHistory));
  });

  test('fertile-quality mucus raises an otherwise-quiet day', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = regularHistory(anchor);
    // A day the predicted curve treats as past the window (ovulation ~ +14).
    final day = anchor.add(const Duration(days: 18));

    final quiet = score(periods, today: day, day: day)!;
    final withMucus = score(
      periods,
      today: day,
      day: day,
      mucus: [
        mucus(anchor.add(const Duration(days: 17)), CervicalMucusType.eggWhite),
        mucus(anchor.add(const Duration(days: 18)), CervicalMucusType.eggWhite),
      ],
    )!;

    expect(withMucus.score, greaterThan(quiet.score + 20));
    expect(withMucus.factors, contains(FertilityFactor.fertileMucusToday));
  });

  test('deterministic: identical inputs give an identical result', () {
    final anchor = DateTime(2026, 6, 1);
    final periods = regularHistory(anchor);
    final today = anchor.add(const Duration(days: 8));
    final a = score(
      periods,
      today: today,
      day: today.add(const Duration(days: 6)),
    );
    final b = score(
      periods,
      today: today,
      day: today.add(const Duration(days: 6)),
    );
    expect(a, equals(b));
  });

  test(
    'clock-injected: shifting every date by N days shifts only the dates',
    () {
      const n = 37;
      final anchor = DateTime(2026, 6, 1);
      final shiftedAnchor = anchor.add(const Duration(days: n));

      List<BbtEntry> bbtFor(DateTime a) => [
        for (var i = 0; i < 6; i++)
          temp(a.add(Duration(days: 4 + i)), 36.40 + (i.isEven ? 0.0 : 0.02)),
        temp(a.add(const Duration(days: 10)), 36.70),
        temp(a.add(const Duration(days: 11)), 36.72),
        temp(a.add(const Duration(days: 12)), 36.69),
      ];
      List<CervicalMucusEntry> mucusFor(DateTime a) => [
        mucus(a.add(const Duration(days: 11)), CervicalMucusType.eggWhite),
      ];

      List<DailyFertilityScore> run(DateTime a) {
        final periods = regularHistory(a);
        final today = a.add(const Duration(days: 13));
        return dailyFertilityScores(
          cycles: deriveCycles(periods),
          bbt: bbtFor(a),
          mucus: mucusFor(a),
          prediction: predict(periods, today),
          today: today,
          days: 6,
        );
      }

      final base = run(anchor);
      final shifted = run(shiftedAnchor);
      expect(shifted, hasLength(base.length));
      expect(base, isNotEmpty);
      for (var i = 0; i < base.length; i++) {
        expect(shifted[i].score, base[i].score, reason: 'score $i');
        expect(
          shifted[i].confidence,
          base[i].confidence,
          reason: 'confidence $i',
        );
        expect(shifted[i].low, base[i].low);
        expect(shifted[i].high, base[i].high);
        expect(shifted[i].factors, base[i].factors, reason: 'factors $i');
        expect(
          shifted[i].date,
          base[i].date.add(const Duration(days: n)),
          reason: 'date $i',
        );
        expect(
          shifted[i].peakDay,
          base[i].peakDay.add(const Duration(days: n)),
        );
      }
    },
  );
}
