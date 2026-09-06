import '../db/app_database.dart';
import '../db/tables.dart';
import '../symptom/symptom_severity.dart';

/// Thrown by [PainRepository.setPain] for input it will not store.
class PainException implements Exception {
  PainException(this.message);
  final String message;
  @override
  String toString() => 'PainException: $message';
}

/// Longest note [PainRepository.setPain] accepts. Generous — a note is a
/// sentence or two — but bounded so one row can't balloon the encrypted DB.
const int kPainNoteMaxLength = 2000;

/// Reads and writes the endometriosis pain / flare log ([PainEntry]) — one row
/// per calendar day (schema v8, p7.5).
///
/// A day with no pain is the **absence of a row**: [clearDay] deletes, and
/// [setPain] rejects [SymptomSeverity.none] rather than storing an "empty"
/// entry. Keyed by `date`, like the flow and BBT logs, and never linked to a
/// [Periods] row.
abstract interface class PainRepository {
  /// The pain logged for [date], or `null` if that day has none.
  Future<PainEntry?> painOn(DateTime date);

  /// Every logged day as a stream that re-emits on any change, newest first.
  Stream<List<PainEntry>> watchAll();

  /// Every logged day, newest first, as a one-shot read.
  Future<List<PainEntry>> allEntries();

  /// Record (or replace) the pain for [date]. Upserts on the day; `created_at`
  /// is preserved when a row already exists.
  ///
  /// Throws [PainException] if [intensity] is [SymptomSeverity.none] (use
  /// [clearDay]) or if [note] is longer than [kPainNoteMaxLength]. [note] is
  /// trimmed; an empty or whitespace-only note is stored as `null`.
  Future<void> setPain(
    DateTime date, {
    required SymptomSeverity intensity,
    PainRegion? region,
    String? note,
    bool isFlare = false,
  });

  /// Remove the pain logged for [date]. A no-op if that day has none.
  Future<void> clearDay(DateTime date);
}
