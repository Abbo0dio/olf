import '../db/app_database.dart';

/// Reads and writes the symptom catalogue ([SymptomType]) and the per-day
/// symptom log ([DailySymptomEntry]).
///
/// The catalogue is user-editable: names can be added, renamed and reordered,
/// and removal is a **soft archive** so historical entries keep their meaning.
/// Day logging is a plain multi-select toggle — there is nothing to validate, so
/// [setSymptom] is idempotent on both edges.
abstract interface class SymptomRepository {
  /// Active (non-archived) catalogue entries, ordered by `sortOrder`, as a
  /// stream that re-emits on any change.
  Stream<List<SymptomType>> watchTypes();

  /// A one-shot read of the active catalogue, ordered by `sortOrder`.
  Future<List<SymptomType>> activeTypes();

  /// Add a custom symptom. Trims [name]; throws [SymptomTypeException] if it is
  /// empty, too long, or clashes (case-insensitively) with an active name. The
  /// new row is appended after the current last `sortOrder`.
  Future<SymptomType> addType(String name);

  /// Rename the catalogue entry [id]. Same validation as [addType], except the
  /// entry's own current name never counts as a clash.
  Future<void> renameType(int id, String name);

  /// Rewrite `sortOrder` for every id in [orderedIds] to its position in the
  /// list (0-based). Ids not present are left untouched.
  Future<void> reorderTypes(List<int> orderedIds);

  /// Soft-delete the catalogue entry [id]: it disappears from [watchTypes] /
  /// [activeTypes] and the pickers, but its [DailySymptomEntry] rows remain.
  Future<void> archiveType(int id);

  /// The set of `symptomTypeId`s marked present on [date] (calendar day).
  Future<Set<int>> symptomsOn(DateTime date);

  /// Every logged entry, newest day first, as a stream that re-emits on change.
  Stream<List<DailySymptomEntry>> watchAllEntries();

  /// Toggle whether [typeId] is present on [date]. `present: true` inserts the
  /// row if missing (a no-op if it exists); `present: false` deletes it (a
  /// no-op if absent).
  Future<void> setSymptom(DateTime date, int typeId, {required bool present});

  /// Remove every symptom entry for [date].
  Future<void> clearDay(DateTime date);
}
