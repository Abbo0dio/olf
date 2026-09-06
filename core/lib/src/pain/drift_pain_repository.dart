import 'package:drift/drift.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';
import '../symptom/symptom_severity.dart';
import 'pain_repository.dart';

/// [PainRepository] backed by the drift [AppDatabase].
class DriftPainRepository implements PainRepository {
  DriftPainRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;

  /// Injectable "now" — keeps the `createdAt` / `updatedAt` stamps deterministic
  /// in tests and the repository offline.
  final DateTime Function() _now;

  @override
  Future<PainEntry?> painOn(DateTime date) {
    final day = dateOnly(date);
    return (_db.select(
      _db.painEntries,
    )..where((t) => t.date.equals(day))).getSingleOrNull();
  }

  @override
  Stream<List<PainEntry>> watchAll() {
    return (_db.select(_db.painEntries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  @override
  Future<List<PainEntry>> allEntries() {
    return (_db.select(_db.painEntries)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .get();
  }

  @override
  Future<void> setPain(
    DateTime date, {
    required SymptomSeverity intensity,
    PainRegion? region,
    String? note,
    bool isFlare = false,
  }) async {
    if (intensity == SymptomSeverity.none) {
      throw PainException(
        'A pain entry needs an intensity. Clear the day instead of logging '
        '"none".',
      );
    }
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.length > kPainNoteMaxLength) {
      throw PainException(
        'Note is too long (${trimmed.length}/$kPainNoteMaxLength characters).',
      );
    }
    final cleanNote = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    final day = dateOnly(date);
    final stamp = _now();
    final existing = await painOn(day);

    if (existing == null) {
      await _db
          .into(_db.painEntries)
          .insert(
            PainEntriesCompanion.insert(
              date: day,
              intensity: intensity,
              region: Value(region),
              note: Value(cleanNote),
              isFlare: Value(isFlare),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
    } else {
      await (_db.update(
        _db.painEntries,
      )..where((t) => t.date.equals(day))).write(
        PainEntriesCompanion(
          intensity: Value(intensity),
          region: Value(region),
          note: Value(cleanNote),
          isFlare: Value(isFlare),
          updatedAt: Value(stamp),
        ),
      );
    }
  }

  @override
  Future<void> clearDay(DateTime date) async {
    final day = dateOnly(date);
    await (_db.delete(_db.painEntries)..where((t) => t.date.equals(day))).go();
  }
}
