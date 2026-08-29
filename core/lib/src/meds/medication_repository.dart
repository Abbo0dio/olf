import '../db/app_database.dart';

/// Reads and writes the user's medication list ([Medication]).
///
/// This is the *list*, not a dose log. Removal is a **soft archive** so a
/// medication can leave the active list without dropping anything a later phase
/// attaches to it. Names are validated (`validateMedicationName`); `dosage` and
/// `notes` are free text with nothing to check.
abstract interface class MedicationRepository {
  /// Active (non-archived) medications, ordered by name (case-insensitive), as
  /// a stream that re-emits on any change.
  Stream<List<Medication>> watchActive();

  /// A one-shot read of the active medications, ordered by name.
  Future<List<Medication>> activeMedications();

  /// Add a medication. Trims [name]; throws [MedicationException] if it is empty
  /// or too long. [dosage] / [notes] are stored as given (trimmed, or `null`
  /// when blank).
  Future<Medication> add(String name, {String? dosage, String? notes});

  /// Edit medication [id]. Same name validation as [add]. Passing `null` for
  /// [dosage] / [notes] clears that field.
  Future<void> edit(
    int id, {
    required String name,
    String? dosage,
    String? notes,
  });

  /// Soft-delete medication [id]: it disappears from [watchActive] /
  /// [activeMedications] but its row remains.
  Future<void> archive(int id);

  /// Restore a previously [archive]d medication [id].
  Future<void> unarchive(int id);
}
