/// Validation for user-defined symptom names (schema v4, p1.5).
///
/// Mirrors `period_validation.dart`: an error enum with a user-facing
/// [SymptomTypeErrorMessage.describe], an exception the repository throws, and a
/// pure `validate…` function the UI can call for inline feedback.
library;

/// The longest a symptom name may be. Kept in step with the `name` column's
/// `withLength(max: …)` in `tables.dart`.
const int maxSymptomNameLength = 40;

/// Why a symptom name was rejected. `null` from [validateSymptomName] means it
/// is acceptable.
enum SymptomTypeError {
  /// The name is empty once surrounding whitespace is removed.
  empty,

  /// The name is longer than [maxSymptomNameLength] characters.
  tooLong,

  /// Another active symptom already has this name (compared case-insensitively).
  duplicate,
}

/// A short, neutral sentence suitable for showing the user.
extension SymptomTypeErrorMessage on SymptomTypeError {
  String describe() => switch (this) {
    SymptomTypeError.empty => 'Give the symptom a name.',
    SymptomTypeError.tooLong =>
      'That name is too long — keep it to $maxSymptomNameLength characters.',
    SymptomTypeError.duplicate => 'You already have a symptom with that name.',
  };
}

/// Thrown by [SymptomRepository] writes when a name fails [validateSymptomName].
class SymptomTypeException implements Exception {
  const SymptomTypeException(this.error);

  final SymptomTypeError error;

  @override
  String toString() => 'SymptomTypeException: ${error.describe()}';
}

/// Validate [name] as a new or renamed symptom.
///
/// [existingActiveNames] is every active symptom's name (the row being renamed
/// may be included). When renaming, pass the row's current name as
/// [editingCurrentName] so a pure case change ("cramps" → "Cramps") is allowed.
///
/// Returns the first problem found, or `null` when the name is acceptable.
/// Rules, in order: empty, too long, duplicate.
SymptomTypeError? validateSymptomName(
  String name, {
  required Iterable<String> existingActiveNames,
  String? editingCurrentName,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return SymptomTypeError.empty;
  if (trimmed.length > maxSymptomNameLength) return SymptomTypeError.tooLong;

  final lower = trimmed.toLowerCase();
  final editingLower = editingCurrentName?.trim().toLowerCase();
  for (final other in existingActiveNames) {
    final otherLower = other.trim().toLowerCase();
    if (editingLower != null && otherLower == editingLower) {
      continue; // the row being renamed — never clashes with itself
    }
    if (otherLower == lower) return SymptomTypeError.duplicate;
  }
  return null;
}
