import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  ReminderSchedule at(ReminderKind kind, int hour, int minute) =>
      ReminderSchedule(kind: kind, hour: hour, minute: minute, enabled: true);

  /// A prediction whose expected next start is [expected] and whose fertile
  /// window opens on [fertileStart].
  CyclePrediction predictionWith({
    required DateTime expected,
    required DateTime fertileStart,
  }) => CyclePrediction(
    nextPeriod: DateRange(
      expected.subtract(const Duration(days: 2)),
      expected.add(const Duration(days: 2)),
    ),
    nextPeriodExpected: expected,
    fertileWindow: DateRange(
      fertileStart,
      fertileStart.add(const Duration(days: 6)),
    ),
    confidence: PredictionConfidence.medium,
    basedOnCycles: 6,
    status: PredictionStatus.upcoming,
    daysPastExpected: null,
  );

  group('fixed daily kinds roll to the next occurrence', () {
    for (final kind in const [
      ReminderKind.medication,
      ReminderKind.bbtPrompt,
    ]) {
      test('$kind — later today stays today', () {
        final today = DateTime(2026, 3, 10, 6, 0);
        expect(
          nextFireTime(
            kind: kind,
            schedule: at(kind, 9, 0),
            prediction: null,
            today: today,
          ),
          DateTime(2026, 3, 10, 9, 0),
        );
      });

      test('$kind — already past rolls to tomorrow', () {
        final today = DateTime(2026, 3, 10, 21, 30);
        expect(
          nextFireTime(
            kind: kind,
            schedule: at(kind, 9, 0),
            prediction: null,
            today: today,
          ),
          DateTime(2026, 3, 11, 9, 0),
        );
      });
    }
  });

  group('upcomingPeriod', () {
    test('fires kUpcomingPeriodLeadDays early at the chosen time', () {
      final today = DateTime(2026, 3, 1, 8, 0);
      final prediction = predictionWith(
        expected: DateTime(2026, 3, 20),
        fertileStart: DateTime(2026, 3, 6),
      );
      final when = nextFireTime(
        kind: ReminderKind.upcomingPeriod,
        schedule: at(ReminderKind.upcomingPeriod, 8, 30),
        prediction: prediction,
        today: today,
      );
      expect(when, DateTime(2026, 3, 20 - kUpcomingPeriodLeadDays, 8, 30));
    });

    test('null when the lead-time instant is already in the past', () {
      final prediction = predictionWith(
        expected: DateTime(2026, 3, 3),
        fertileStart: DateTime(2026, 2, 18),
      );
      expect(
        nextFireTime(
          kind: ReminderKind.upcomingPeriod,
          schedule: at(ReminderKind.upcomingPeriod, 9, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 2, 12, 0),
        ),
        isNull,
      );
    });

    test('null when there is no prediction', () {
      expect(
        nextFireTime(
          kind: ReminderKind.upcomingPeriod,
          schedule: at(ReminderKind.upcomingPeriod, 9, 0),
          prediction: null,
          today: DateTime(2026, 3, 1),
        ),
        isNull,
      );
    });
  });

  group('fertileWindow', () {
    test('anchors on the fertile-window start at the chosen time', () {
      final prediction = predictionWith(
        expected: DateTime(2026, 3, 20),
        fertileStart: DateTime(2026, 3, 6),
      );
      expect(
        nextFireTime(
          kind: ReminderKind.fertileWindow,
          schedule: at(ReminderKind.fertileWindow, 7, 15),
          prediction: prediction,
          today: DateTime(2026, 3, 1),
        ),
        DateTime(2026, 3, 6, 7, 15),
      );
    });

    test('null once the window start is past', () {
      final prediction = predictionWith(
        expected: DateTime(2026, 3, 20),
        fertileStart: DateTime(2026, 3, 6),
      );
      expect(
        nextFireTime(
          kind: ReminderKind.fertileWindow,
          schedule: at(ReminderKind.fertileWindow, 9, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 7),
        ),
        isNull,
      );
    });

    test('null when there is no prediction', () {
      expect(
        nextFireTime(
          kind: ReminderKind.fertileWindow,
          schedule: at(ReminderKind.fertileWindow, 9, 0),
          prediction: null,
          today: DateTime(2026, 3, 1),
        ),
        isNull,
      );
    });
  });

  group('latePeriodCheckIn', () {
    final prediction = predictionWith(
      expected: DateTime(2026, 3, 20),
      fertileStart: DateTime(2026, 3, 6),
    );

    test('null while the grace period has not elapsed', () {
      expect(
        nextFireTime(
          kind: ReminderKind.latePeriodCheckIn,
          schedule: at(ReminderKind.latePeriodCheckIn, 18, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 21, 23, 59),
        ),
        isNull,
      );
    });

    test('fires once today is at/after expected + kLateCheckInGraceDays', () {
      final when = nextFireTime(
        kind: ReminderKind.latePeriodCheckIn,
        schedule: at(ReminderKind.latePeriodCheckIn, 18, 0),
        prediction: prediction,
        today: DateTime(2026, 3, 22, 18, 0),
      );
      expect(when, DateTime(2026, 3, 20 + kLateCheckInGraceDays, 18, 0));
    });

    test('null when there is no prediction', () {
      expect(
        nextFireTime(
          kind: ReminderKind.latePeriodCheckIn,
          schedule: at(ReminderKind.latePeriodCheckIn, 9, 0),
          prediction: null,
          today: DateTime(2026, 4, 1),
        ),
        isNull,
      );
    });
  });

  test('isEventRelativeReminder splits the kinds correctly', () {
    expect(isEventRelativeReminder(ReminderKind.medication), isFalse);
    expect(isEventRelativeReminder(ReminderKind.bbtPrompt), isFalse);
    expect(isEventRelativeReminder(ReminderKind.upcomingPeriod), isTrue);
    expect(isEventRelativeReminder(ReminderKind.fertileWindow), isTrue);
    expect(isEventRelativeReminder(ReminderKind.latePeriodCheckIn), isTrue);
  });

  group('overrideHour (p4.2 learned logging hour)', () {
    final prediction = predictionWith(
      expected: DateTime(2026, 3, 20),
      fertileStart: DateTime(2026, 3, 6),
    );

    test('replaces the scheduled time for an event-relative kind, minutes '
        'zeroed', () {
      final when = nextFireTime(
        kind: ReminderKind.upcomingPeriod,
        schedule: at(ReminderKind.upcomingPeriod, 9, 45),
        prediction: prediction,
        today: DateTime(2026, 3, 1),
        overrideHour: 7,
      );
      expect(when, DateTime(2026, 3, 18, 7, 0));
    });

    test('applies to fertileWindow and latePeriodCheckIn too', () {
      expect(
        nextFireTime(
          kind: ReminderKind.fertileWindow,
          schedule: at(ReminderKind.fertileWindow, 9, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 1),
          overrideHour: 20,
        ),
        DateTime(2026, 3, 6, 20, 0),
      );
      expect(
        nextFireTime(
          kind: ReminderKind.latePeriodCheckIn,
          schedule: at(ReminderKind.latePeriodCheckIn, 18, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 22, 23, 0),
          overrideHour: 8,
        ),
        DateTime(2026, 3, 22, 8, 0),
      );
    });

    test('is ignored for the fixed daily kinds', () {
      for (final kind in const [
        ReminderKind.medication,
        ReminderKind.bbtPrompt,
      ]) {
        final when = nextFireTime(
          kind: kind,
          schedule: at(kind, 9, 0),
          prediction: null,
          today: DateTime(2026, 3, 10, 6, 0),
          overrideHour: 3,
        );
        expect(when, DateTime(2026, 3, 10, 9, 0), reason: '$kind ignores it');
      }
    });

    test('null overrideHour is exactly the p4.1 behaviour', () {
      DateTime? call({int? overrideHour}) => nextFireTime(
        kind: ReminderKind.upcomingPeriod,
        schedule: at(ReminderKind.upcomingPeriod, 8, 30),
        prediction: prediction,
        today: DateTime(2026, 3, 1),
        overrideHour: overrideHour,
      );
      expect(call(), DateTime(2026, 3, 18, 8, 30));
      expect(call(overrideHour: null), call());
    });

    test('the override can move the fire time into the past → null', () {
      // Window start is 2026-03-06; today is the 6th at 08:00. A scheduled
      // 09:00 would still be ahead, but a learned 06:00 is already behind.
      expect(
        nextFireTime(
          kind: ReminderKind.fertileWindow,
          schedule: at(ReminderKind.fertileWindow, 9, 0),
          prediction: prediction,
          today: DateTime(2026, 3, 6, 8, 0),
          overrideHour: 6,
        ),
        isNull,
      );
    });
  });
}
