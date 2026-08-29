import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import 'birth_control.dart';
import 'birth_control_repository.dart';

/// [BirthControlRepository] backed by the drift [AppDatabase].
class DriftBirthControlRepository implements BirthControlRepository {
  DriftBirthControlRepository(
    this._db, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<List<BirthControlEntry>> watchAll() {
    return (_db.select(_db.birthControlEntries)..orderBy([
          (t) => OrderingTerm(expression: t.startedOn, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  SimpleSelectStatement<$BirthControlEntriesTable, BirthControlEntry>
  _currentSelect() => _db.select(_db.birthControlEntries)
    ..where((t) => t.endedOn.isNull())
    ..orderBy([
      (t) => OrderingTerm(expression: t.startedOn, mode: OrderingMode.desc),
    ])
    ..limit(1);

  @override
  Future<BirthControlEntry?> current() => _currentSelect().getSingleOrNull();

  @override
  Stream<BirthControlEntry?> watchCurrent() =>
      _currentSelect().watchSingleOrNull();

  @override
  Future<BirthControlEntry> switchTo(
    BirthControlMethod method, {
    DateTime? startedOn,
  }) async {
    final start = dateOnly(startedOn ?? _now());
    final error = validateBirthControlDates(
      startedOn: start,
      today: dateOnly(_now()),
    );
    if (error != null) throw BirthControlException(error);

    final stamp = _now();
    return _db.transaction(() async {
      final open = await current();
      if (open != null) {
        // End the previous method the day before the new one starts — but never
        // before its own start (same-day switch ends it on its start date).
        final priorEnd = addDays(start, -1).isBefore(dateOnly(open.startedOn))
            ? dateOnly(open.startedOn)
            : addDays(start, -1);
        await (_db.update(
          _db.birthControlEntries,
        )..where((t) => t.id.equals(open.id))).write(
          BirthControlEntriesCompanion(
            endedOn: Value(priorEnd),
            updatedAt: Value(stamp),
          ),
        );
      }
      final id = await _db
          .into(_db.birthControlEntries)
          .insert(
            BirthControlEntriesCompanion.insert(
              method: method,
              startedOn: start,
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
      return (_db.select(
        _db.birthControlEntries,
      )..where((t) => t.id.equals(id))).getSingle();
    });
  }

  @override
  Future<void> stop({DateTime? endedOn}) async {
    final open = await current();
    if (open == null) return;
    final end = dateOnly(endedOn ?? _now());
    if (end.isBefore(dateOnly(open.startedOn))) {
      throw const BirthControlException(BirthControlError.endBeforeStart);
    }
    await (_db.update(
      _db.birthControlEntries,
    )..where((t) => t.id.equals(open.id))).write(
      BirthControlEntriesCompanion(
        endedOn: Value(end),
        updatedAt: Value(_now()),
      ),
    );
  }

  @override
  Future<void> edit(
    int id, {
    required DateTime startedOn,
    DateTime? endedOn,
    String? notes,
  }) async {
    final start = dateOnly(startedOn);
    final end = endedOn == null ? null : dateOnly(endedOn);
    final error = validateBirthControlDates(
      startedOn: start,
      endedOn: end,
      today: dateOnly(_now()),
    );
    if (error != null) throw BirthControlException(error);

    final trimmedNotes = notes?.trim() ?? '';
    await (_db.update(
      _db.birthControlEntries,
    )..where((t) => t.id.equals(id))).write(
      BirthControlEntriesCompanion(
        startedOn: Value(start),
        endedOn: Value(end),
        notes: Value(trimmedNotes.isEmpty ? null : trimmedNotes),
        updatedAt: Value(_now()),
      ),
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(
      _db.birthControlEntries,
    )..where((t) => t.id.equals(id))).go();
  }
}
