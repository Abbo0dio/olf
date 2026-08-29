import 'package:meta/meta.dart';

import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';

/// The end of a pregnancy the user chose to record (p1.11).
///
/// Deliberately just two, non-clinical: a loss, or a birth. Full
/// pregnancy / TTC / postpartum *modes* are Phase 7 — this is only the marker
/// the cycle engine needs so it stops treating the gap as one long cycle.
enum PregnancyEndKind {
  /// A miscarriage / pregnancy loss.
  loss,

  /// A birth. Followed by a postpartum stretch until periods return.
  birth,
}

extension PregnancyEndKindMapping on PregnancyEndKind {
  /// The stored [CycleEventType] for this kind.
  CycleEventType get eventType => switch (this) {
    PregnancyEndKind.loss => CycleEventType.pregnancyLoss,
    PregnancyEndKind.birth => CycleEventType.birth,
  };
}

/// `null` if [type] is not a pregnancy-end event.
PregnancyEndKind? pregnancyEndKindOf(CycleEventType type) => switch (type) {
  CycleEventType.pregnancyLoss => PregnancyEndKind.loss,
  CycleEventType.birth => PregnancyEndKind.birth,
  CycleEventType.periodStart => null,
};

/// A recorded pregnancy-end marker — a [PregnancyEndKind] on a calendar date.
@immutable
class PregnancyEvent {
  PregnancyEvent({required this.id, required this.kind, required DateTime date})
    : date = dateOnly(date);

  /// `cycle_events` row id — the handle for deleting it.
  final int id;

  final PregnancyEndKind kind;

  /// Calendar date the pregnancy ended (time-of-day dropped).
  final DateTime date;

  /// Build from a drift row, or `null` if the row is a `periodStart`.
  static PregnancyEvent? fromRow(CycleEvent row) {
    final kind = pregnancyEndKindOf(row.type);
    return kind == null
        ? null
        : PregnancyEvent(id: row.id, kind: kind, date: row.date);
  }

  @override
  bool operator ==(Object other) =>
      other is PregnancyEvent &&
      other.id == id &&
      other.kind == kind &&
      other.date == date;

  @override
  int get hashCode => Object.hash(id, kind, date);

  @override
  String toString() => 'PregnancyEvent(id: $id, kind: ${kind.name}, $date)';
}

/// The most recent pregnancy-end marker in [events], or `null` if there are
/// none. Ties on date are broken by the higher id (the later entry).
PregnancyEvent? mostRecentPregnancyEnd(Iterable<PregnancyEvent> events) {
  PregnancyEvent? latest;
  for (final e in events) {
    if (latest == null ||
        e.date.isAfter(latest.date) ||
        (e.date == latest.date && e.id > latest.id)) {
      latest = e;
    }
  }
  return latest;
}

/// Where the user is relative to a recorded pregnancy end.
enum PregnancyRecoveryState {
  /// No pregnancy-end recorded, or a period has been logged since the most
  /// recent one — normal cycle tracking applies.
  none,

  /// A loss is the most recent pregnancy-end and no period has been logged
  /// after it yet.
  awaitingCyclesAfterLoss,

  /// A birth is the most recent pregnancy-end and no period has been logged
  /// after it yet — postpartum.
  postpartum,
}

/// Classify the user's state from their [events] and [periods].
///
/// `none` as soon as any period starts strictly after the most recent
/// pregnancy-end — the thin post-event history then makes predictions resume
/// gently on their own (see `RobustPredictor`).
PregnancyRecoveryState pregnancyRecoveryState({
  required Iterable<PregnancyEvent> events,
  required Iterable<Period> periods,
}) {
  final latest = mostRecentPregnancyEnd(events);
  if (latest == null) return PregnancyRecoveryState.none;

  final resumed = periods.any(
    (p) => dateOnly(p.startDate).isAfter(latest.date),
  );
  if (resumed) return PregnancyRecoveryState.none;

  return switch (latest.kind) {
    PregnancyEndKind.loss => PregnancyRecoveryState.awaitingCyclesAfterLoss,
    PregnancyEndKind.birth => PregnancyRecoveryState.postpartum,
  };
}
