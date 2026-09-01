import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'logging_activity_repository.dart';
import 'preferred_hour.dart';

/// [LoggingActivityRepository] backed by the drift [AppDatabase].
///
/// Five typed `createdAt >= since` reads — one per user-logging table — merged,
/// sorted newest-first and capped in Dart. Read-only, existing columns, **no
/// schema change**.
class DriftLoggingActivityRepository implements LoggingActivityRepository {
  DriftLoggingActivityRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<DateTime>> recentLogTimestamps({
    required DateTime since,
    int limit = kPreferredHourQueryLimit,
  }) async {
    final periods = await (_db.select(
      _db.periods,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();
    final flows = await (_db.select(
      _db.dailyFlows,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();
    final symptoms = await (_db.select(
      _db.dailySymptomEntries,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();
    final bbt = await (_db.select(
      _db.bbtEntries,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();
    final mucus = await (_db.select(
      _db.cervicalMucusEntries,
    )..where((t) => t.createdAt.isBiggerOrEqualValue(since))).get();

    final stamps = <DateTime>[
      ...periods.map((r) => r.createdAt),
      ...flows.map((r) => r.createdAt),
      ...symptoms.map((r) => r.createdAt),
      ...bbt.map((r) => r.createdAt),
      ...mucus.map((r) => r.createdAt),
    ]..sort((a, b) => b.compareTo(a));

    return stamps.length > limit ? stamps.sublist(0, limit) : stamps;
  }
}
