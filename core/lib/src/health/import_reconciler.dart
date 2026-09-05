import 'package:meta/meta.dart';

import '../date_math.dart';
import 'health_sample.dart';

/// A lightweight projection of one locally-stored row, as the reconciler needs
/// to see it.
///
/// The caller builds these from its own tables — `bbt_entries` and `daily_flows`
/// grow `source` + `external_id` columns in schema v7 (p6.1) precisely so this
/// view can be populated. The reconciler never touches storage; [localId] is an
/// opaque handle the caller uses to apply the resulting plan back (e.g. the
/// row's date-key as an ISO string).
@immutable
class LocalSampleView {
  const LocalSampleView({
    required this.localId,
    required this.type,
    required this.day,
    required this.value,
    required this.unit,
    required this.source,
    this.externalId,
  });

  final String localId;
  final HealthSampleType type;

  /// The calendar day this row is for. Compared time-stripped.
  final DateTime day;
  final double value;
  final HealthUnit unit;
  final HealthDataSource source;
  final String? externalId;

  @override
  bool operator ==(Object other) =>
      other is LocalSampleView &&
      other.localId == localId &&
      other.type == type &&
      other.day == day &&
      other.value == value &&
      other.unit == unit &&
      other.source == source &&
      other.externalId == externalId;

  @override
  int get hashCode =>
      Object.hash(localId, type, day, value, unit, source, externalId);

  @override
  String toString() =>
      'LocalSampleView($localId, $type, $day, $value $unit, $source, '
      'externalId: $externalId)';
}

/// Why an incoming sample could not be auto-applied.
enum ConflictReason {
  /// The matching local row is a value the user typed ([HealthDataSource.manual]).
  /// The user's value always wins unless they resolve the conflict themselves.
  manualDisagreement,

  /// The matching local row came from a different platform than this import.
  crossSourceDisagreement,
}

/// One incoming sample that matched an existing local row whose value differs
/// and cannot be auto-updated. The caller surfaces these for the user to
/// resolve (p6.4 conflict-review screen).
@immutable
class ReconciliationConflict {
  const ReconciliationConflict({
    required this.localId,
    required this.local,
    required this.incoming,
    required this.reason,
  });

  final String localId;
  final LocalSampleView local;
  final HealthSample incoming;
  final ConflictReason reason;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationConflict &&
      other.localId == localId &&
      other.local == local &&
      other.incoming == incoming &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(localId, local, incoming, reason);

  @override
  String toString() =>
      'ReconciliationConflict($localId, $reason, incoming: $incoming)';
}

/// One incoming sample that matched a non-manual local row of the same source
/// with a revised value — safe to overwrite in place.
@immutable
class ReconciliationUpdate {
  const ReconciliationUpdate({required this.localId, required this.incoming});

  final String localId;
  final HealthSample incoming;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationUpdate &&
      other.localId == localId &&
      other.incoming == incoming;

  @override
  int get hashCode => Object.hash(localId, incoming);

  @override
  String toString() => 'ReconciliationUpdate($localId, $incoming)';
}

/// One incoming sample already present locally, byte-for-byte — nothing to do.
@immutable
class ReconciliationSkip {
  const ReconciliationSkip({required this.localId, required this.incoming});

  final String localId;
  final HealthSample incoming;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationSkip &&
      other.localId == localId &&
      other.incoming == incoming;

  @override
  int get hashCode => Object.hash(localId, incoming);

  @override
  String toString() => 'ReconciliationSkip($localId, $incoming)';
}

/// The output of [ImportReconciler.reconcile] — a pure value object the caller
/// applies to its own storage. The reconciler itself writes nothing.
@immutable
class ReconciliationPlan {
  ReconciliationPlan({
    required List<HealthSample> inserts,
    required List<ReconciliationUpdate> updates,
    required List<ReconciliationConflict> conflicts,
    required List<ReconciliationSkip> skipped,
  }) : inserts = List.unmodifiable(inserts),
       updates = List.unmodifiable(updates),
       conflicts = List.unmodifiable(conflicts),
       skipped = List.unmodifiable(skipped);

  /// Incoming samples with no local match — insert as-is.
  final List<HealthSample> inserts;

  /// Incoming samples that revise a non-manual same-source local row.
  final List<ReconciliationUpdate> updates;

  /// Incoming samples that disagree with a manual, or a differently-sourced,
  /// local row — needs the user.
  final List<ReconciliationConflict> conflicts;

  /// Incoming samples already stored identically.
  final List<ReconciliationSkip> skipped;

  bool get isEmpty =>
      inserts.isEmpty &&
      updates.isEmpty &&
      conflicts.isEmpty &&
      skipped.isEmpty;

  int get total =>
      inserts.length + updates.length + conflicts.length + skipped.length;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationPlan &&
      _listEq(other.inserts, inserts) &&
      _listEq(other.updates, updates) &&
      _listEq(other.conflicts, conflicts) &&
      _listEq(other.skipped, skipped);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(inserts),
    Object.hashAll(updates),
    Object.hashAll(conflicts),
    Object.hashAll(skipped),
  );

  @override
  String toString() =>
      'ReconciliationPlan(inserts: ${inserts.length}, updates: ${updates.length}, '
      'conflicts: ${conflicts.length}, skipped: ${skipped.length})';
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Merges a batch of external [HealthSample]s against the user's existing rows
/// without ever creating a duplicate or clobbering a value the user typed.
///
/// Pure and deterministic: the same inputs in any order produce the same
/// [ReconciliationPlan]. It reads nothing and writes nothing — the caller owns
/// storage.
///
/// **Matching.** An incoming sample matches a local row by [externalId] first;
/// failing that, by `(type, day)`. **Hard rules.** A [HealthDataSource.manual]
/// local row is never in [ReconciliationPlan.updates] — a disagreement with it
/// is always a [ReconciliationConflict]. A `(type, day)` match against a
/// different-source row is a conflict, not an update.
class ImportReconciler {
  const ImportReconciler({this.tolerance = 0.01});

  /// Absolute delta below which two same-unit values are "the same reading"
  /// (0.01 °C, or an exact flow level). Guards against float noise on
  /// round-trip.
  final double tolerance;

  ReconciliationPlan reconcile({
    required List<LocalSampleView> local,
    required List<HealthSample> incoming,
  }) {
    final byExternalId = <String, LocalSampleView>{};
    final byTypeDay = <(HealthSampleType, DateTime), LocalSampleView>{};
    for (final row in local) {
      final ext = row.externalId;
      if (ext != null) byExternalId[ext] = row;
      byTypeDay[(row.type, dateOnly(row.day))] = row;
    }

    final inserts = <HealthSample>[];
    final updates = <ReconciliationUpdate>[];
    final conflicts = <ReconciliationConflict>[];
    final skipped = <ReconciliationSkip>[];

    // Process in a stable order so the plan is independent of the caller's
    // input ordering.
    final ordered = [...incoming]..sort(_stableOrder);

    for (final sample in ordered) {
      final match = _matchFor(sample, byExternalId, byTypeDay);

      if (match == null) {
        inserts.add(sample);
        continue;
      }

      final sameUnit = match.unit == sample.unit;
      final sameValue =
          sameUnit && (match.value - sample.value).abs() <= tolerance;
      final sameSource = match.source == sample.source;

      if (sameValue && sameSource) {
        skipped.add(
          ReconciliationSkip(localId: match.localId, incoming: sample),
        );
        continue;
      }

      if (match.source == HealthDataSource.manual) {
        conflicts.add(
          ReconciliationConflict(
            localId: match.localId,
            local: match,
            incoming: sample,
            reason: ConflictReason.manualDisagreement,
          ),
        );
        continue;
      }

      if (!sameSource) {
        if (sameValue) {
          skipped.add(
            ReconciliationSkip(localId: match.localId, incoming: sample),
          );
        } else {
          conflicts.add(
            ReconciliationConflict(
              localId: match.localId,
              local: match,
              incoming: sample,
              reason: ConflictReason.crossSourceDisagreement,
            ),
          );
        }
        continue;
      }

      // Same non-manual source, value revised — safe in-place update.
      updates.add(
        ReconciliationUpdate(localId: match.localId, incoming: sample),
      );
    }

    return ReconciliationPlan(
      inserts: inserts,
      updates: updates,
      conflicts: conflicts,
      skipped: skipped,
    );
  }

  LocalSampleView? _matchFor(
    HealthSample sample,
    Map<String, LocalSampleView> byExternalId,
    Map<(HealthSampleType, DateTime), LocalSampleView> byTypeDay,
  ) {
    final ext = sample.externalId;
    if (ext != null) {
      final hit = byExternalId[ext];
      if (hit != null) return hit;
    }
    return byTypeDay[(sample.type, sample.day)];
  }

  static int _stableOrder(HealthSample a, HealthSample b) {
    final byStart = a.startAt.compareTo(b.startAt);
    if (byStart != 0) return byStart;
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    final byValue = a.value.compareTo(b.value);
    if (byValue != 0) return byValue;
    return (a.externalId ?? '').compareTo(b.externalId ?? '');
  }
}
