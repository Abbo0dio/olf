import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end,
    createdAt: epoch,
    updatedAt: epoch,
  );

  PregnancyEvent event(PregnancyEndKind kind, DateTime date, {int? id}) =>
      PregnancyEvent(id: id ?? nextId++, kind: kind, date: date);

  setUp(() => nextId = 1);

  group('kind <-> event-type mapping', () {
    test('round-trips both ways', () {
      expect(PregnancyEndKind.loss.eventType, CycleEventType.pregnancyLoss);
      expect(PregnancyEndKind.birth.eventType, CycleEventType.birth);
      expect(
        pregnancyEndKindOf(CycleEventType.pregnancyLoss),
        PregnancyEndKind.loss,
      );
      expect(pregnancyEndKindOf(CycleEventType.birth), PregnancyEndKind.birth);
      expect(pregnancyEndKindOf(CycleEventType.periodStart), isNull);
    });

    test('PregnancyEvent.fromRow ignores a periodStart row', () {
      final loss = CycleEvent(
        id: 3,
        type: CycleEventType.pregnancyLoss,
        date: DateTime(2026, 5, 4, 9),
        createdAt: epoch,
      );
      final start = CycleEvent(
        id: 4,
        type: CycleEventType.periodStart,
        date: DateTime(2026, 5, 20),
        createdAt: epoch,
      );

      final parsed = PregnancyEvent.fromRow(loss);
      expect(parsed, isNotNull);
      expect(parsed!.id, 3);
      expect(parsed.kind, PregnancyEndKind.loss);
      expect(parsed.date, DateTime(2026, 5, 4)); // time-of-day dropped
      expect(PregnancyEvent.fromRow(start), isNull);
    });
  });

  group('mostRecentPregnancyEnd', () {
    test('null with no events', () {
      expect(mostRecentPregnancyEnd(const []), isNull);
    });

    test('picks the latest date, breaking ties by the higher id', () {
      final older = event(PregnancyEndKind.loss, DateTime(2025, 1, 1), id: 1);
      final sameDayA = event(
        PregnancyEndKind.loss,
        DateTime(2026, 6, 1),
        id: 5,
      );
      final sameDayB = event(
        PregnancyEndKind.birth,
        DateTime(2026, 6, 1),
        id: 9,
      );

      expect(mostRecentPregnancyEnd([older, sameDayB, sameDayA]), sameDayB);
    });
  });

  group('pregnancyRecoveryState', () {
    test('none when nothing is recorded', () {
      expect(
        pregnancyRecoveryState(
          events: const [],
          periods: [period(DateTime(2026, 3, 1))],
        ),
        PregnancyRecoveryState.none,
      );
    });

    test('postpartum after a birth with no period since', () {
      expect(
        pregnancyRecoveryState(
          events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
          periods: [period(DateTime(2026, 1, 5), DateTime(2026, 1, 9))],
        ),
        PregnancyRecoveryState.postpartum,
      );
    });

    test('awaiting cycles after a loss with no period since', () {
      expect(
        pregnancyRecoveryState(
          events: [event(PregnancyEndKind.loss, DateTime(2026, 4, 10))],
          periods: const [],
        ),
        PregnancyRecoveryState.awaitingCyclesAfterLoss,
      );
    });

    test('back to none once a period starts after the most recent end', () {
      expect(
        pregnancyRecoveryState(
          events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
          periods: [
            period(DateTime(2026, 1, 5)),
            period(DateTime(2026, 6, 2)), // after the birth
          ],
        ),
        PregnancyRecoveryState.none,
      );
    });

    test('a period on the same day as the birth does not count as resumed', () {
      expect(
        pregnancyRecoveryState(
          events: [event(PregnancyEndKind.birth, DateTime(2026, 4, 10))],
          periods: [period(DateTime(2026, 4, 10))],
        ),
        PregnancyRecoveryState.postpartum,
      );
    });
  });
}
