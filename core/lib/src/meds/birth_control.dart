import '../date_math.dart';
import '../db/tables.dart';

/// Display metadata for [BirthControlMethod].
extension BirthControlMethodInfo on BirthControlMethod {
  /// Short, neutral label for a chip or dropdown.
  String get label => switch (this) {
    BirthControlMethod.pill => 'Pill',
    BirthControlMethod.patch => 'Patch',
    BirthControlMethod.ring => 'Ring',
    BirthControlMethod.injection => 'Injection',
    BirthControlMethod.iud => 'IUD',
    BirthControlMethod.implant => 'Implant',
    BirthControlMethod.condom => 'Condom',
    BirthControlMethod.other => 'Other',
  };
}

/// Why a birth-control entry's dates were rejected. `null` from
/// [validateBirthControlDates] means they are acceptable.
enum BirthControlError {
  /// `startedOn` is after today.
  startInFuture,

  /// `endedOn` is before `startedOn`.
  endBeforeStart,
}

/// A short, neutral sentence suitable for showing the user.
extension BirthControlErrorMessage on BirthControlError {
  String describe() => switch (this) {
    BirthControlError.startInFuture => "The start date can't be in the future.",
    BirthControlError.endBeforeStart =>
      "The end date can't be before the start date.",
  };
}

/// Thrown by `BirthControlRepository` writes when dates fail
/// [validateBirthControlDates].
class BirthControlException implements Exception {
  const BirthControlException(this.error);

  final BirthControlError error;

  @override
  String toString() => 'BirthControlException: ${error.describe()}';
}

/// Validate a birth-control entry's dates as calendar days.
///
/// [today] defaults to `DateTime.now()`; pass it in tests. Returns the first
/// problem found, or `null` when the dates are acceptable.
BirthControlError? validateBirthControlDates({
  required DateTime startedOn,
  DateTime? endedOn,
  DateTime? today,
}) {
  final start = dateOnly(startedOn);
  final now = dateOnly(today ?? DateTime.now());
  if (start.isAfter(now)) return BirthControlError.startInFuture;
  if (endedOn != null && dateOnly(endedOn).isBefore(start)) {
    return BirthControlError.endBeforeStart;
  }
  return null;
}
