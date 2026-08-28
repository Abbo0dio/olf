import 'package:meta/meta.dart';

import '../date_math.dart';
import '../db/app_database.dart';

/// The user-editable fields of a period, before it is persisted.
///
/// Persistence ([Period]) adds `id`, `createdAt` and `updatedAt`.
@immutable
class PeriodDraft {
  const PeriodDraft({required this.start, this.end});

  /// Calendar date the period started. Time-of-day is ignored.
  final DateTime start;

  /// Calendar date the period ended, or `null` if ongoing / not yet recorded.
  final DateTime? end;

  PeriodDraft copyWith({
    DateTime? start,
    DateTime? end,
    bool clearEnd = false,
  }) {
    return PeriodDraft(
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodDraft && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Why a [PeriodDraft] was rejected. `null` from [validatePeriod] means valid.
enum PeriodValidationError {
  /// The end date falls before the start date.
  endBeforeStart,

  /// The start date is in the future.
  startInFuture,

  /// The end date is in the future.
  endInFuture,

  /// The range shares one or more calendar days with a period already logged.
  overlapsExisting,
}

/// A short, neutral sentence suitable for showing the user.
extension PeriodValidationErrorMessage on PeriodValidationError {
  String describe() => switch (this) {
    PeriodValidationError.endBeforeStart =>
      'The end date is before the start date.',
    PeriodValidationError.startInFuture =>
      'The start date is in the future — log a period once it has begun.',
    PeriodValidationError.endInFuture => 'The end date is in the future.',
    PeriodValidationError.overlapsExisting =>
      'This overlaps a period you have already logged.',
  };
}

/// Thrown by [PeriodRepository] writes when a draft fails [validatePeriod].
class PeriodValidationException implements Exception {
  const PeriodValidationException(this.error);

  final PeriodValidationError error;

  @override
  String toString() => 'PeriodValidationException: ${error.describe()}';
}

/// Validate [draft] as a new or edited period.
///
/// [existing] is every period already stored; when editing, pass the row's id
/// as [editingId] so it is not compared against itself. [today] is the
/// reference "now" — injected so the future-date checks are deterministic and
/// need no clock.
///
/// Returns the first problem found, or `null` when the draft is acceptable.
/// Rules, in order: end-before-start, start-in-future, end-in-future, overlap.
/// Overlap is inclusive on both ends and treats a `null` end as open-ended, so
/// a period with no recorded end blocks anything logged on or after its start.
PeriodValidationError? validatePeriod(
  PeriodDraft draft, {
  required Iterable<Period> existing,
  required DateTime today,
  int? editingId,
}) {
  final start = dateOnly(draft.start);
  final end = draft.end == null ? null : dateOnly(draft.end!);
  final reference = dateOnly(today);

  if (end != null && end.isBefore(start)) {
    return PeriodValidationError.endBeforeStart;
  }
  if (start.isAfter(reference)) {
    return PeriodValidationError.startInFuture;
  }
  if (end != null && end.isAfter(reference)) {
    return PeriodValidationError.endInFuture;
  }

  for (final period in existing) {
    if (period.id == editingId) continue;
    final otherStart = dateOnly(period.startDate);
    final otherEnd = period.endDate == null ? null : dateOnly(period.endDate!);
    if (_overlapsInclusive(start, end, otherStart, otherEnd)) {
      return PeriodValidationError.overlapsExisting;
    }
  }

  return null;
}

/// Far-future stand-in for an open-ended (`null`) period end.
final DateTime _openEnd = DateTime(9999, 12, 31);

bool _overlapsInclusive(
  DateTime aStart,
  DateTime? aEnd,
  DateTime bStart,
  DateTime? bEnd,
) {
  final aEndEff = aEnd ?? _openEnd;
  final bEndEff = bEnd ?? _openEnd;
  return !aStart.isAfter(bEndEff) && !bStart.isAfter(aEndEff);
}
