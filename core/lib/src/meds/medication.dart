/// Validation + error vocabulary for medication entries (schema v6, p1.7).
///
/// Mirrors `symptom_validation.dart`: an error enum with a user-facing
/// [MedicationErrorMessage.describe], an exception the repository throws, and a
/// pure `validate…` function the UI can call for inline feedback.
library;

/// The longest a medication name may be. Kept in step with the `name` column's
/// `withLength(max: …)` in `tables.dart`.
const int maxMedicationNameLength = 80;

/// Why a medication name was rejected. `null` from [validateMedicationName]
/// means it is acceptable.
enum MedicationError {
  /// The name is empty once surrounding whitespace is removed.
  nameEmpty,

  /// The name is longer than [maxMedicationNameLength] characters.
  nameTooLong,
}

/// A short, neutral sentence suitable for showing the user.
extension MedicationErrorMessage on MedicationError {
  String describe() => switch (this) {
    MedicationError.nameEmpty => 'Give the medication a name.',
    MedicationError.nameTooLong =>
      'That name is too long — keep it to $maxMedicationNameLength characters.',
  };
}

/// Thrown by `MedicationRepository` writes when a name fails
/// [validateMedicationName].
class MedicationException implements Exception {
  const MedicationException(this.error);

  final MedicationError error;

  @override
  String toString() => 'MedicationException: ${error.describe()}';
}

/// Validate [name] as a new or edited medication name. Returns the first
/// problem found, or `null` when the name is acceptable.
MedicationError? validateMedicationName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return MedicationError.nameEmpty;
  if (trimmed.length > maxMedicationNameLength) {
    return MedicationError.nameTooLong;
  }
  return null;
}
