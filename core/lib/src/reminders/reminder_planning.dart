import '../db/tables.dart';
import '../prediction/predictor.dart';
import 'reminder_schedule.dart';

/// How many days before the predicted period start the `upcomingPeriod`
/// reminder fires.
const int kUpcomingPeriodLeadDays = 2;

/// How many days after the predicted period start must pass with nothing logged
/// before the `latePeriodCheckIn` reminder is due.
const int kLateCheckInGraceDays = 2;

/// The `ReminderKind`s whose fire day is anchored on the cycle forecast rather
/// than a fixed daily clock. The rest ([ReminderKind.medication],
/// [ReminderKind.bbtPrompt]) fire at a plain daily time.
const Set<ReminderKind> eventRelativeReminderKinds = {
  ReminderKind.upcomingPeriod,
  ReminderKind.fertileWindow,
  ReminderKind.latePeriodCheckIn,
};

/// Whether [kind] is anchored on the cycle forecast.
bool isEventRelativeReminder(ReminderKind kind) =>
    eventRelativeReminderKinds.contains(kind);

/// The next local [DateTime] a reminder of [kind] should fire, given the user's
/// stored [schedule] (time-of-day + on/off is not consulted here — callers only
/// plan enabled reminders), the current [prediction], and [today].
///
/// Pure wall-clock arithmetic — no `DateTime.now()`, no time zones, DST-agnostic
/// (mirrors [nextOccurrence]). Returns `null` when there is nothing to schedule
/// yet:
///
///  * [ReminderKind.medication] / [ReminderKind.bbtPrompt] — the next daily
///    occurrence of `schedule.hour:minute` at or after [today]
///    (via [nextOccurrence]); never `null`.
///  * [ReminderKind.upcomingPeriod] — [kUpcomingPeriodLeadDays] before
///    `prediction.nextPeriodExpected`, at the scheduled time; `null` if there is
///    no prediction or that instant is already before [today].
///  * [ReminderKind.fertileWindow] — `prediction.fertileWindow.start` at the
///    scheduled time; `null` if there is no prediction or it is already past.
///  * [ReminderKind.latePeriodCheckIn] — [kLateCheckInGraceDays] after
///    `prediction.nextPeriodExpected`, at the scheduled time; `null` unless
///    [today] is already at or after that instant (only nudge once genuinely
///    late) or there is no prediction.
DateTime? nextFireTime({
  required ReminderKind kind,
  required ReminderSchedule schedule,
  required CyclePrediction? prediction,
  required DateTime today,
}) {
  switch (kind) {
    case ReminderKind.medication:
    case ReminderKind.bbtPrompt:
      return nextOccurrence(schedule, from: today);

    case ReminderKind.upcomingPeriod:
      if (prediction == null) return null;
      final at = _atScheduledTime(
        _addDays(prediction.nextPeriodExpected, -kUpcomingPeriodLeadDays),
        schedule,
      );
      return at.isBefore(today) ? null : at;

    case ReminderKind.fertileWindow:
      if (prediction == null) return null;
      final at = _atScheduledTime(prediction.fertileWindow.start, schedule);
      return at.isBefore(today) ? null : at;

    case ReminderKind.latePeriodCheckIn:
      if (prediction == null) return null;
      final at = _atScheduledTime(
        _addDays(prediction.nextPeriodExpected, kLateCheckInGraceDays),
        schedule,
      );
      return today.isBefore(at) ? null : at;
  }
}

/// [day] with the time-of-day replaced by [schedule]'s `hour:minute`
/// (seconds/millis zeroed).
DateTime _atScheduledTime(DateTime day, ReminderSchedule schedule) =>
    DateTime(day.year, day.month, day.day, schedule.hour, schedule.minute);

/// Calendar-day shift that stays on the same wall-clock date arithmetic as the
/// rest of the module (no `Duration`, so a DST boundary can't drift the day).
DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);
