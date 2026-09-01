import 'preferred_hour.dart';

/// Read-only access to *when* the user has recently logged anything — the input
/// `learnPreferredHour` (p4.2) needs to time the forecast-anchored reminders.
///
/// It exposes only `createdAt` timestamps, never row contents, and never writes.
abstract interface class LoggingActivityRepository {
  /// The `createdAt` instant of every user-logged row created at or after
  /// [since] — across periods, daily flow, symptom entries, BBT and
  /// cervical-mucus entries — newest first, capped at [limit].
  Future<List<DateTime>> recentLogTimestamps({
    required DateTime since,
    int limit = kPreferredHourQueryLimit,
  });
}
