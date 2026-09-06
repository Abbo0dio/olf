import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end ?? start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  PregnancyEvent event(PregnancyEndKind kind, DateTime date) =>
      PregnancyEvent(id: nextId++, kind: kind, date: date);

  setUp(() => nextId = 1);

  test('null when no pregnancy loss / birth is recorded', () {
    expect(
      derivePostpartumCycleReturn(
        events: const [],
        periods: [period(DateTime(2026, 1, 5))],
        today: DateTime(2026, 3, 1),
      ),
      isNull,
    );
  });

  group('awaiting the first post-event period', () {
    test('birth with no period since → awaitingFirstPeriod, no read', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
        periods: [period(DateTime(2026, 1, 5))], // before the birth
        today: DateTime(2026, 5, 20),
      );

      expect(result, isNotNull);
      expect(result!.eventKind, PregnancyEndKind.birth);
      expect(result.eventDate, DateTime(2026, 4, 10));
      expect(result.daysSinceEvent, 40);
      expect(result.firstPeriodLogged, isFalse);
      expect(result.firstPeriodDate, isNull);
      expect(result.postEventCycleCount, 0);
      expect(result.regularity, isNull);
      expect(result.settling, PostpartumSettling.awaitingFirstPeriod);
    });

    test('loss is handled the same way', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.loss, DateTime(2026, 4, 10))],
        periods: const [],
        today: DateTime(2026, 4, 24),
      );

      expect(result!.eventKind, PregnancyEndKind.loss);
      expect(result.daysSinceEvent, 14);
      expect(result.settling, PostpartumSettling.awaitingFirstPeriod);
      expect(result.regularity, isNull);
    });

    test(
      'a period on the event date does not count as the cycle returning',
      () {
        final result = derivePostpartumCycleReturn(
          events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
          periods: [period(DateTime(2026, 4, 10))],
          today: DateTime(2026, 5, 1),
        );

        expect(result!.firstPeriodLogged, isFalse);
        expect(result.settling, PostpartumSettling.awaitingFirstPeriod);
      },
    );
  });

  group('first post-event period logged, not enough for a read', () {
    test('one post-event period → firstCycleLogged, no regularity', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
        periods: [period(DateTime(2026, 7, 1))],
        today: DateTime(2026, 7, 10),
      );

      expect(result!.firstPeriodLogged, isTrue);
      expect(result.firstPeriodDate, DateTime(2026, 7, 1));
      expect(result.postEventCycleCount, 0);
      expect(result.regularity, isNull);
      expect(result.settling, PostpartumSettling.firstCycleLogged);
    });

    test('two post-event periods = one completed cycle, still no read', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.loss, DateTime(2026, 4, 10))],
        periods: [period(DateTime(2026, 6, 1)), period(DateTime(2026, 6, 30))],
        today: DateTime(2026, 7, 5),
      );

      expect(result!.postEventCycleCount, 1);
      expect(result.regularity, isNull);
      expect(result.settling, PostpartumSettling.firstCycleLogged);
    });
  });

  group('two or more completed post-event cycles → a variability read', () {
    test('lengths within a normal spread → settling', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.birth, DateTime(2026, 3, 1))],
        periods: [
          period(DateTime(2026, 6, 1)),
          period(DateTime(2026, 7, 1)), // 30-day cycle
          period(DateTime(2026, 7, 29)), // 28-day cycle
        ],
        today: DateTime(2026, 8, 2),
      );

      expect(result!.postEventCycleCount, 2);
      expect(result.regularity, CycleRegularity.regular);
      expect(result.settling, PostpartumSettling.settling);
      expect(result.postEventCycleStats.shortestCycleLength, 28);
      expect(result.postEventCycleStats.longestCycleLength, 30);
    });

    test('lengths still swinging widely → stillVariable', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.birth, DateTime(2026, 3, 1))],
        periods: [
          period(DateTime(2026, 6, 1)),
          period(DateTime(2026, 6, 27)), // 26-day cycle
          period(DateTime(2026, 8, 10)), // 44-day cycle
        ],
        today: DateTime(2026, 8, 20),
      );

      expect(result!.postEventCycleCount, 2);
      expect(result.regularity, CycleRegularity.irregular);
      expect(result.settling, PostpartumSettling.stillVariable);
    });

    test('a loss with a settled post-event history is read the same way', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.loss, DateTime(2026, 1, 15))],
        periods: [
          period(DateTime(2026, 3, 1)),
          period(DateTime(2026, 3, 29)),
          period(DateTime(2026, 4, 26)),
        ],
        today: DateTime(2026, 5, 1),
      );

      expect(result!.eventKind, PregnancyEndKind.loss);
      expect(result.settling, PostpartumSettling.settling);
    });
  });

  group('clock + edge cases', () {
    test('daysSinceEvent is driven by the injected clock', () {
      final events = [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))];
      expect(
        derivePostpartumCycleReturn(
          events: events,
          periods: const [],
          today: DateTime(2026, 4, 11),
        )!.daysSinceEvent,
        1,
      );
      expect(
        derivePostpartumCycleReturn(
          events: events,
          periods: const [],
          today: DateTime(2027, 4, 10),
        )!.daysSinceEvent,
        365,
      );
    });

    test('a future-dated event clamps daysSinceEvent to 0', () {
      final result = derivePostpartumCycleReturn(
        events: [event(PregnancyEndKind.loss, DateTime(2026, 6, 1))],
        periods: const [],
        today: DateTime(2026, 5, 1),
      );

      expect(result!.daysSinceEvent, 0);
    });

    test('the most recent pregnancy end anchors the view', () {
      final result = derivePostpartumCycleReturn(
        events: [
          event(PregnancyEndKind.loss, DateTime(2025, 1, 1)),
          event(PregnancyEndKind.birth, DateTime(2026, 4, 10)),
        ],
        periods: [period(DateTime(2026, 5, 20))],
        today: DateTime(2026, 6, 1),
      );

      expect(result!.eventKind, PregnancyEndKind.birth);
      expect(result.eventDate, DateTime(2026, 4, 10));
      expect(result.firstPeriodDate, DateTime(2026, 5, 20));
    });
  });
}
