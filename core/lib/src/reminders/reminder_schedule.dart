import '../db/tables.dart';

/// A recurring daily reminder as a plain value: which [ReminderKind] it is for,
/// the local wall-clock time it should fire, and whether it is on.
///
/// This is the pure "schedule model" the app layer turns into a platform
/// notification. It carries **no free text** — the notification's wording is a
/// fixed generic string chosen in the app, so nothing about a medication can
/// leak onto a lock screen.
class ReminderSchedule {
  const ReminderSchedule({
    required this.kind,
    required this.hour,
    required this.minute,
    required this.enabled,
  });

  final ReminderKind kind;

  /// 0–23, local time.
  final int hour;

  /// 0–59, local time.
  final int minute;

  final bool enabled;

  /// A copy with the given fields replaced.
  ReminderSchedule copyWith({int? hour, int? minute, bool? enabled}) =>
      ReminderSchedule(
        kind: kind,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSchedule &&
      other.kind == kind &&
      other.hour == hour &&
      other.minute == minute &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(kind, hour, minute, enabled);

  @override
  String toString() =>
      'ReminderSchedule(${kind.name}, '
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}, '
      '${enabled ? 'on' : 'off'})';
}

/// Why a reminder time was rejected. `null` from [validateReminderTime] means
/// it is acceptable.
enum ReminderError {
  /// `hour` is outside 0–23.
  hourOutOfRange,

  /// `minute` is outside 0–59.
  minuteOutOfRange,
}

/// A short, neutral sentence suitable for showing the user.
extension ReminderErrorMessage on ReminderError {
  String describe() => switch (this) {
    ReminderError.hourOutOfRange => 'Pick an hour between 0 and 23.',
    ReminderError.minuteOutOfRange => 'Pick a minute between 0 and 59.',
  };
}

/// Thrown by `ReminderRepository.save` when the time fails
/// [validateReminderTime].
class ReminderException implements Exception {
  const ReminderException(this.error);

  final ReminderError error;

  @override
  String toString() => 'ReminderException: ${error.describe()}';
}

/// Validate [hour] / [minute] as a wall-clock time. Returns the first problem
/// found, or `null` when the time is acceptable.
ReminderError? validateReminderTime(int hour, int minute) {
  if (hour < 0 || hour > 23) return ReminderError.hourOutOfRange;
  if (minute < 0 || minute > 59) return ReminderError.minuteOutOfRange;
  return null;
}

/// The next local [DateTime] at [schedule]'s `hour:minute`, at or after [from].
///
/// If today's occurrence is still ahead of [from] (strictly — an exact match
/// counts as "now, fire it") it is returned; otherwise tomorrow's. The result
/// carries seconds and milliseconds zeroed. [schedule.enabled] is not consulted
/// — callers decide whether to schedule at all.
DateTime nextOccurrence(ReminderSchedule schedule, {required DateTime from}) {
  final todayAt = DateTime(
    from.year,
    from.month,
    from.day,
    schedule.hour,
    schedule.minute,
  );
  if (!todayAt.isBefore(from)) return todayAt;
  return DateTime(
    from.year,
    from.month,
    from.day + 1,
    schedule.hour,
    schedule.minute,
  );
}
