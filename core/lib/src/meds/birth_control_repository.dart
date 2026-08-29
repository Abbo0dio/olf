import '../db/app_database.dart';
import '../db/tables.dart';

/// Reads and writes the user's birth-control method history
/// ([BirthControlEntry]).
///
/// One row per stretch of time on a method; `endedOn == null` marks the current
/// one. Switching methods is [switchTo]: it ends the open row (if any) and
/// inserts a new open one, so the history stays intact. Dates are validated
/// (`validateBirthControlDates`).
abstract interface class BirthControlRepository {
  /// Every entry, newest start first, as a stream that re-emits on any change.
  Stream<List<BirthControlEntry>> watchAll();

  /// The current entry (`endedOn == null`), or `null` if none is set.
  Future<BirthControlEntry?> current();

  /// The current entry as a stream, re-emitting on any change.
  Stream<BirthControlEntry?> watchCurrent();

  /// Start using [method] as of [startedOn] (defaults to today). Ends the
  /// current open entry on the day before [startedOn] (never before its own
  /// start). Throws [BirthControlException] if [startedOn] is in the future.
  Future<BirthControlEntry> switchTo(
    BirthControlMethod method, {
    DateTime? startedOn,
  });

  /// End the current open entry as of [endedOn] (defaults to today). A no-op if
  /// nothing is open. Throws [BirthControlException] if [endedOn] is before the
  /// entry's start.
  Future<void> stop({DateTime? endedOn});

  /// Edit entry [id]'s dates and/or notes. Throws [BirthControlException] on an
  /// invalid range.
  Future<void> edit(
    int id, {
    required DateTime startedOn,
    DateTime? endedOn,
    String? notes,
  });

  /// Hard-delete entry [id].
  Future<void> delete(int id);
}
