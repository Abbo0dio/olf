import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  const predictor = RobustPredictor();
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end,
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// Periods starting 1 Jan 2026, each [gaps] days after the previous.
  List<Period> runOf(List<int> gaps) {
    var day = DateTime(2026, 1, 1);
    final out = <Period>[period(day)];
    for (final g in gaps) {
      day = day.add(Duration(days: g));
      out.add(period(day));
    }
    return out;
  }

  CyclePrediction? predictFrom(List<Period> periods, DateTime today) =>
      predictor.predict(cycles: deriveCycles(periods), today: today);

  setUp(() => nextId = 1);

  test('no history → no prediction (never a fabricated date)', () {
    expect(predictor.predict(cycles: const [], today: epoch), isNull);
    expect(
      predictFrom([period(DateTime(2026, 3, 1))], DateTime(2026, 3, 10)),
      isNull,
    );
  });

  test('one completed cycle → a humble low-confidence estimate', () {
    final p = predictFrom([
      period(DateTime(2026, 3, 1)),
      period(DateTime(2026, 3, 29)),
    ], DateTime(2026, 4, 1))!;

    expect(p.basedOnCycles, 1);
    expect(p.confidence, PredictionConfidence.low);
    // anchor 29 Mar + 28-day cycle
    expect(p.nextPeriodExpected, DateTime(2026, 4, 26));
    // still a range, never a single day
    expect(p.nextPeriod.start, DateTime(2026, 4, 25));
    expect(p.nextPeriod.end, DateTime(2026, 4, 27));
    expect(p.nextPeriod.lengthInDays, 3);
  });

  group('a regular history', () {
    // 1 Jan, 29 Jan, 26 Feb, 26 Mar — three completed 28-day cycles.
    List<Period> history() => runOf([28, 28, 28]);

    test('projects the median length with high confidence', () {
      final p = predictFrom(history(), DateTime(2026, 4, 1))!;
      expect(p.basedOnCycles, 3);
      expect(p.confidence, PredictionConfidence.high);
      expect(p.nextPeriodExpected, DateTime(2026, 4, 23)); // 26 Mar + 28
      expect(p.nextPeriod.start, DateTime(2026, 4, 22));
      expect(p.nextPeriod.end, DateTime(2026, 4, 24));
    });

    test('fertile window is a ~7-day span before the expected period', () {
      final p = predictFrom(history(), DateTime(2026, 4, 1))!;
      // ovulation ≈ 23 Apr − 14 = 9 Apr; window 4–10 Apr
      expect(p.fertileWindow.start, DateTime(2026, 4, 4));
      expect(p.fertileWindow.end, DateTime(2026, 4, 10));
      expect(p.fertileWindow.lengthInDays, 7);
      expect(p.fertileWindow.end.isBefore(p.nextPeriod.start), isTrue);
    });

    test('today before the window → upcoming', () {
      final p = predictFrom(history(), DateTime(2026, 4, 1))!;
      expect(p.status, PredictionStatus.upcoming);
      expect(p.daysPastExpected, isNull);
    });

    test('today inside the window → dueNow', () {
      final p = predictFrom(history(), DateTime(2026, 4, 23))!;
      expect(p.status, PredictionStatus.dueNow);
      expect(p.daysPastExpected, isNull);
    });

    test('today past the window → overdue, and the estimate does NOT roll '
        'forward', () {
      final p = predictFrom(history(), DateTime(2026, 6, 1))!;
      expect(p.status, PredictionStatus.overdue);
      expect(p.isOverdue, isTrue);
      // still anchored to 26 Mar + 28, not advanced by another cycle
      expect(p.nextPeriodExpected, DateTime(2026, 4, 23));
      expect(p.nextPeriod.start, DateTime(2026, 4, 22));
      // 23 Apr → 1 Jun
      expect(p.daysPastExpected, 39);
    });
  });

  test('an irregular history → low confidence and a visibly wider window', () {
    // cycle lengths 24, 34, 27, 31 → spread 10, median 29
    final p = predictFrom(runOf([24, 34, 27, 31]), DateTime(2026, 4, 1))!;
    expect(p.basedOnCycles, 4);
    expect(p.confidence, PredictionConfidence.low);
    expect(p.nextPeriodExpected, DateTime(2026, 5, 26)); // 27 Apr + 29
    expect(p.nextPeriod.start, DateTime(2026, 5, 21)); // 27 Apr + 24
    expect(p.nextPeriod.end, DateTime(2026, 5, 31)); // 27 Apr + 34
    expect(p.nextPeriod.lengthInDays, 11);
  });

  test('editing history moves the estimate on recompute', () {
    final before = predictFrom([
      period(DateTime(2026, 4, 1)),
      period(DateTime(2026, 5, 1)),
    ], DateTime(2026, 4, 15))!;
    final after = predictFrom([
      period(DateTime(2026, 4, 1)),
      period(DateTime(2026, 5, 5)),
    ], DateTime(2026, 4, 15))!;
    // anchor +4 days and cycle length +4 days → expected shifts +8
    expect(daysBetween(before.nextPeriodExpected, after.nextPeriodExpected), 8);
  });

  test(
    'a likely gap in history forces low confidence despite steady cycles',
    () {
      // four clean 28-day cycles, but with a 70-day hole in the middle
      final p = predictFrom(
        runOf([28, 28, 70, 28, 28]),
        DateTime(2026, 7, 10),
      )!;
      expect(p.confidence, PredictionConfidence.low);
    },
  );

  test('a metronomic history still yields a range, never one day', () {
    final p = predictFrom(runOf([28, 28, 28, 28]), DateTime(2026, 4, 1))!;
    expect(p.nextPeriod.lengthInDays, greaterThanOrEqualTo(3));
    expect(p.nextPeriod.start == p.nextPeriod.end, isFalse);
  });

  test('mostly-regular history with two cycles → medium confidence', () {
    // lengths 27 and 32 → spread 5 → mostlyRegular
    final p = predictFrom(runOf([27, 32]), DateTime(2026, 3, 1))!;
    expect(p.basedOnCycles, 2);
    expect(p.confidence, PredictionConfidence.medium);
  });

  group('across a pregnancy loss / birth (p1.11)', () {
    CyclePrediction? predictWith(
      List<Period> periods,
      List<PregnancyEvent> events,
      DateTime today,
    ) => predictor.predict(
      cycles: deriveCycles(periods, pregnancyEvents: events),
      today: today,
    );

    PregnancyEvent pregEvent(PregnancyEndKind kind, DateTime date) =>
        PregnancyEvent(id: nextId++, kind: kind, date: date);

    test('no forecast while the open cycle covers a birth', () {
      expect(
        predictWith(
          runOf([28, 28, 28]), // solid pre-pregnancy history
          [pregEvent(PregnancyEndKind.birth, DateTime(2026, 6, 1))],
          DateTime(2026, 9, 1),
        ),
        isNull,
      );
    });

    test('no forecast while the open cycle covers a loss', () {
      expect(
        predictWith(runOf([28, 28]), [
          pregEvent(PregnancyEndKind.loss, DateTime(2026, 4, 15)),
        ], DateTime(2026, 5, 20)),
        isNull,
      );
    });

    test('one logged period after the birth is still not enough', () {
      final periods = [
        period(DateTime(2026, 1, 1)),
        period(DateTime(2026, 1, 29)),
        period(DateTime(2026, 2, 26)),
        period(DateTime(2026, 10, 1)), // first period back
      ];
      expect(
        predictWith(periods, [
          pregEvent(PregnancyEndKind.birth, DateTime(2026, 6, 1)),
        ], DateTime(2026, 10, 15)),
        isNull, // only the open post-birth cycle — nothing completed yet
      );
    });

    test('forecast resumes on post-event cycles, not the old ones', () {
      // Pre-birth cycles run a tight 28 days; post-birth they run 40.
      final periods = [
        period(DateTime(2026, 1, 1)),
        period(DateTime(2026, 1, 29)),
        period(DateTime(2026, 2, 26)),
        period(DateTime(2026, 10, 1)), // first period back
        period(DateTime(2026, 11, 10)), // +40
        period(DateTime(2026, 12, 20)), // +40, opens the current cycle
      ];
      final p = predictWith(periods, [
        pregEvent(PregnancyEndKind.birth, DateTime(2026, 6, 1)),
      ], DateTime(2026, 12, 25))!;

      // Anchored on the last start + the *post-birth* 40-day length, not 28.
      expect(p.nextPeriodExpected, DateTime(2027, 1, 29)); // 20 Dec + 40
      expect(p.basedOnCycles, 2); // the two completed post-birth cycles
    });

    test('an old loss with cycles fully resumed is business as usual', () {
      final periods = [
        period(DateTime(2026, 1, 1)),
        period(DateTime(2026, 5, 1)), // loss falls in this interval
        period(DateTime(2026, 5, 29)),
        period(DateTime(2026, 6, 26)),
        period(DateTime(2026, 7, 24)),
      ];
      final p = predictWith(periods, [
        pregEvent(PregnancyEndKind.loss, DateTime(2026, 3, 15)),
      ], DateTime(2026, 8, 1))!;
      expect(p.nextPeriodExpected, DateTime(2026, 8, 21)); // 24 Jul + 28
      expect(p.basedOnCycles, 3);
    });
  });
}
