import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'retention_window.dart';

/// What one auto-deletion sweep removed.
///
/// Counts only — never any entry content — so it is safe to log
/// (`requirements.md` §3: no PHI in logs).
class RetentionSweepResult {
  const RetentionSweepResult({
    required this.cutoff,
    required this.deletedByTable,
  });

  /// A sweep that did nothing (the window is [RetentionWindow.off]).
  const RetentionSweepResult.none()
    : cutoff = null,
      deletedByTable = const <String, int>{};

  /// Entries strictly older than this calendar date were removed. `null` when
  /// the window was `off`.
  final DateTime? cutoff;

  /// Rows removed per table (tables with nothing to remove are omitted).
  final Map<String, int> deletedByTable;

  int get total => deletedByTable.values.fold(0, (a, b) => a + b);

  bool get didAnything => total > 0;

  @override
  String toString() =>
      'RetentionSweepResult(cutoff: $cutoff, total: $total, '
      'byTable: $deletedByTable)';
}

/// Deletes dated entries older than a [RetentionWindow] (p2.3).
///
/// Lives in `core` because it operates directly on the drift schema. It only
/// ever issues `DELETE`s — no schema change, no migration. Non-dated tables
/// (`medications`, `symptom_types`, `reminders`, `app_settings`) are untouched;
/// a still-current birth-control method (`ended_on IS NULL`) is kept regardless
/// of how long ago it started, and a period that straddles the cutoff
/// (`COALESCE(end_date, start_date)`) is kept.
class RetentionService {
  RetentionService(this._db);

  final AppDatabase _db;

  /// The `DELETE ... WHERE <expr> < :cutoff` predicate per table, in
  /// child-before-parent order. Exposed so a test can assert it covers every
  /// dated table.
  static const Map<String, String> deleteWhere = <String, String>{
    'daily_symptom_entries': 'date < ?',
    'daily_flows': 'date < ?',
    'bbt_entries': 'date < ?',
    'cervical_mucus_entries': 'date < ?',
    'cycle_events': 'date < ?',
    'periods': 'COALESCE(end_date, start_date) < ?',
    'birth_control_entries': 'ended_on IS NOT NULL AND ended_on < ?',
  };

  /// Remove every dated entry older than [window] relative to [now]. A no-op
  /// (and a zero result) when [window] is [RetentionWindow.off]. Runs in a
  /// single transaction.
  Future<RetentionSweepResult> sweep({
    required DateTime now,
    required RetentionWindow window,
  }) async {
    final cutoff = window.cutoff(now);
    if (cutoff == null) return const RetentionSweepResult.none();

    final deleted = <String, int>{};
    await _db.transaction(() async {
      for (final entry in deleteWhere.entries) {
        final n = await _db.customUpdate(
          'DELETE FROM ${entry.key} WHERE ${entry.value}',
          variables: [Variable.withDateTime(cutoff)],
          updates: {
            _db.allTables.firstWhere((t) => t.actualTableName == entry.key),
          },
          updateKind: UpdateKind.delete,
        );
        if (n > 0) deleted[entry.key] = n;
      }
    });
    return RetentionSweepResult(cutoff: cutoff, deletedByTable: deleted);
  }
}
