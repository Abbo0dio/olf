import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import 'period_repository.dart';
import 'period_validation.dart';

/// [PeriodRepository] backed by the drift [AppDatabase].
class DriftPeriodRepository implements PeriodRepository {
  DriftPeriodRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps future-date validation and the `updatedAt` stamp
  /// deterministic in tests, and keeps the repository offline (no ambient clock
  /// beyond this).
  final DateTime Function() _now;

  @override
  Future<List<Period>> allPeriods() => _query().get();

  @override
  Stream<List<Period>> watchPeriods() => _query().watch();

  @override
  Future<int> addPeriod(PeriodDraft draft) async {
    final existing = await allPeriods();
    final error = validatePeriod(draft, existing: existing, today: _now());
    if (error != null) throw PeriodValidationException(error);

    final stamp = _now();
    return _db
        .into(_db.periods)
        .insert(
          PeriodsCompanion.insert(
            startDate: dateOnly(draft.start),
            endDate: Value(_endOrNull(draft)),
            createdAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
        );
  }

  @override
  Future<void> updatePeriod(int id, PeriodDraft draft) async {
    final existing = await allPeriods();
    if (!existing.any((p) => p.id == id)) return;

    final error = validatePeriod(
      draft,
      existing: existing,
      today: _now(),
      editingId: id,
    );
    if (error != null) throw PeriodValidationException(error);

    await (_db.update(_db.periods)..where((t) => t.id.equals(id))).write(
      PeriodsCompanion(
        startDate: Value(dateOnly(draft.start)),
        endDate: Value(_endOrNull(draft)),
        updatedAt: Value(_now()),
      ),
    );
  }

  @override
  Future<void> deletePeriod(int id) async {
    await (_db.delete(_db.periods)..where((t) => t.id.equals(id))).go();
  }

  static DateTime? _endOrNull(PeriodDraft draft) =>
      draft.end == null ? null : dateOnly(draft.end!);

  SimpleSelectStatement<$PeriodsTable, Period> _query() {
    return _db.select(_db.periods)..orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
    ]);
  }
}
