import 'package:meta/meta.dart';

import '../date_math.dart';
import 'health_sample.dart';
import 'known_devices.dart';
import 'source_precedence.dart';

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
    this.sourceDevice,
    this.isSleepingWrist = false,
  });

  final String localId;
  final HealthSampleType type;

  /// The calendar day this row is for. Compared time-stripped.
  final DateTime day;
  final double value;
  final HealthUnit unit;
  final HealthDataSource source;
  final String? externalId;

  /// Free-form device / app tag for the row's origin (schema v11, p8.2), or
  /// `null` for a manual row or one imported before device attribution existed.
  /// Never a matching key — used only to tell two devices apart on one day.
  final String? sourceDevice;

  /// `true` when this stored row is a passive Apple-Watch sleeping-wrist
  /// reading (p8.1a `measurement_kind`). Feeds the p8.6 precedence classifier's
  /// sleeping-wrist rank; never affects matching. The caller sets it when
  /// building the view from a `sleepingWrist` `bbt_entries` row.
  final bool isSleepingWrist;

  @override
  bool operator ==(Object other) =>
      other is LocalSampleView &&
      other.localId == localId &&
      other.type == type &&
      other.day == day &&
      other.value == value &&
      other.unit == unit &&
      other.source == source &&
      other.externalId == externalId &&
      other.sourceDevice == sourceDevice &&
      other.isSleepingWrist == isSleepingWrist;

  @override
  int get hashCode => Object.hash(
    localId,
    type,
    day,
    value,
    unit,
    source,
    externalId,
    sourceDevice,
    isSleepingWrist,
  );

  @override
  String toString() =>
      'LocalSampleView($localId, $type, $day, $value $unit, $source, '
      'externalId: $externalId, sourceDevice: $sourceDevice, '
      'isSleepingWrist: $isSleepingWrist)';
}

/// Why an incoming sample could not be auto-applied.
enum ConflictReason {
  /// The matching local row is a value the user typed ([HealthDataSource.manual]).
  /// The user's value always wins unless they resolve the conflict themselves.
  manualDisagreement,

  /// The matching local row came from a different platform than this import.
  crossSourceDisagreement,

  /// The matching row and this sample came from the **same platform** but from
  /// two **different devices** (both [HealthSample.sourceDevice] known and
  /// unequal) and their values disagree (schema v11, p8.2). olf will not pick a
  /// winner — the multi-source precedence policy is p8.6 — so the user resolves
  /// it. The "matching row" here may be another sample from the *same* import
  /// batch that landed first (by the reconciler's stable order).
  crossDeviceDisagreement,
}

/// One incoming sample that matched an existing local row whose value differs
/// and cannot be auto-updated. The caller surfaces these for the user to
/// resolve (p6.4 conflict-review screen).
@immutable
class ReconciliationConflict {
  ReconciliationConflict({
    required this.localId,
    required this.local,
    required this.incoming,
    required this.reason,
    List<HealthSample> alsoContending = const [],
  }) : alsoContending = List.unmodifiable(alsoContending);

  final String localId;
  final LocalSampleView local;
  final HealthSample incoming;
  final ConflictReason reason;

  /// Extra automatic readings for the **same `(type, day)`** that also disagree
  /// and share the top precedence tier with [incoming] (p8.6). Empty for an
  /// ordinary two-way conflict; non-empty only when three or more sources tie
  /// for a day, so the review screen can show every value at once. [local] and
  /// [incoming] carry the first two; this list carries the rest, in the
  /// reconciler's stable order.
  final List<HealthSample> alsoContending;

  /// This conflict with [alsoContending] replaced — used by the reconciler's
  /// finalize pass to fold sibling same-slot conflicts into one N-way card.
  ReconciliationConflict withAlsoContending(List<HealthSample> extra) =>
      ReconciliationConflict(
        localId: localId,
        local: local,
        incoming: incoming,
        reason: reason,
        alsoContending: extra,
      );

  @override
  bool operator ==(Object other) =>
      other is ReconciliationConflict &&
      other.localId == localId &&
      other.local == local &&
      other.incoming == incoming &&
      other.reason == reason &&
      _listEq(other.alsoContending, alsoContending);

  @override
  int get hashCode => Object.hash(
    localId,
    local,
    incoming,
    reason,
    Object.hashAll(alsoContending),
  );

  @override
  String toString() =>
      'ReconciliationConflict($localId, $reason, incoming: $incoming'
      '${alsoContending.isEmpty ? '' : ', +${alsoContending.length} more'})';
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

/// One incoming sample dropped because a **higher precedence-tier** reading
/// already holds this `(type, day)` slot (p8.6). Not an error and not
/// user-visible — olf simply keeps the better reading. The dropped value is not
/// persisted by olf but remains in the OS health store, so if the winning
/// source is later deleted a re-sync lets the runner-up win.
@immutable
class ReconciliationSupersede {
  const ReconciliationSupersede({
    required this.localId,
    required this.incoming,
  });

  /// The [LocalSampleView.localId] (or pending id) of the winning reading.
  final String localId;

  /// The lower-tier incoming sample that was set aside.
  final HealthSample incoming;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationSupersede &&
      other.localId == localId &&
      other.incoming == incoming;

  @override
  int get hashCode => Object.hash(localId, incoming);

  @override
  String toString() => 'ReconciliationSupersede($localId, $incoming)';
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
    List<ReconciliationSupersede> superseded = const [],
  }) : inserts = List.unmodifiable(inserts),
       updates = List.unmodifiable(updates),
       conflicts = List.unmodifiable(conflicts),
       skipped = List.unmodifiable(skipped),
       superseded = List.unmodifiable(superseded);

  /// Incoming samples with no local match — insert as-is.
  final List<HealthSample> inserts;

  /// Incoming samples that revise a non-manual same-source local row.
  final List<ReconciliationUpdate> updates;

  /// Incoming samples that disagree with a manual, or a differently-sourced,
  /// local row — needs the user.
  final List<ReconciliationConflict> conflicts;

  /// Incoming samples already stored identically.
  final List<ReconciliationSkip> skipped;

  /// Incoming samples dropped in favour of a higher precedence-tier reading for
  /// the same day (p8.6). Not surfaced to the user and not counted in the sync
  /// summary — olf just keeps the better reading.
  final List<ReconciliationSupersede> superseded;

  bool get isEmpty =>
      inserts.isEmpty &&
      updates.isEmpty &&
      conflicts.isEmpty &&
      skipped.isEmpty &&
      superseded.isEmpty;

  int get total =>
      inserts.length +
      updates.length +
      conflicts.length +
      skipped.length +
      superseded.length;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationPlan &&
      _listEq(other.inserts, inserts) &&
      _listEq(other.updates, updates) &&
      _listEq(other.conflicts, conflicts) &&
      _listEq(other.skipped, skipped) &&
      _listEq(other.superseded, superseded);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(inserts),
    Object.hashAll(updates),
    Object.hashAll(conflicts),
    Object.hashAll(skipped),
    Object.hashAll(superseded),
  );

  @override
  String toString() =>
      'ReconciliationPlan(inserts: ${inserts.length}, updates: ${updates.length}, '
      'conflicts: ${conflicts.length}, skipped: ${skipped.length}, '
      'superseded: ${superseded.length})';
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
/// failing that, by `(type, day)` — and a sample that is itself *inserted* this
/// pass is registered under both keys, so a second incoming sample for the same
/// not-yet-stored `(type, day)` matches the first (p8.2). **Hard rules.** When
/// the values already agree (within [tolerance]) there is nothing to do — the
/// sample is skipped regardless of source or device. Otherwise: a
/// [HealthDataSource.manual] local row is never in [ReconciliationPlan.updates]
/// — a *disagreement* with it is always a [ReconciliationConflict]; a
/// `(type, day)` match against a different-`source` row that disagrees is a
/// [ConflictReason.crossSourceDisagreement] conflict.
///
/// **p8.6 multi-source precedence.** When a same-`source`, non-manual
/// disagreement is between readings of **different precedence tiers**
/// ([sourcePrecedenceTier] — dedicated device > Apple-Watch wrist > bare
/// platform sample), the higher tier wins deterministically: the incoming
/// sample becomes a [ReconciliationUpdate] if it outranks the stored row, or a
/// [ReconciliationSupersede] (silently dropped) if the stored row outranks it.
/// Only a **same-tier** disagreement between two different known devices is a
/// [ConflictReason.crossDeviceDisagreement] the user must resolve; three or more
/// same-tier sources for one day fold into a single conflict carrying the rest
/// in [ReconciliationConflict.alsoContending]. A disagreement with a
/// [HealthDataSource.manual] row is **always** a conflict — never auto-resolved.
/// Everything else that is same-`source`, same-or-unknown device, same tier,
/// non-manual, revised → an in-place update.
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
    final superseded = <ReconciliationSupersede>[];

    // p8.2: `localId`s of the stand-in views registered for samples inserted
    // *this pass* — so we can tell "matched another same-batch insert" from
    // "matched a stored row" and keep the single-source plan shape unchanged.
    final pendingLocalIds = <String>{};
    // p8.6: the actual sample behind each pending view, so a later higher-tier
    // reading for the same day can replace it in [inserts].
    final pendingSampleByLocalId = <String, HealthSample>{};

    // Process in a stable order so the plan is independent of the caller's
    // input ordering.
    final ordered = [...incoming]..sort(_stableOrder);

    void registerPendingInsert(HealthSample sample) {
      final pending = _pendingView(sample);
      pendingLocalIds.add(pending.localId);
      pendingSampleByLocalId[pending.localId] = sample;
      byTypeDay[(sample.type, dateOnly(sample.day))] = pending;
      final ext = sample.externalId;
      if (ext != null) byExternalId.putIfAbsent(ext, () => pending);
    }

    for (final sample in ordered) {
      final match = _matchFor(sample, byExternalId, byTypeDay);

      if (match == null) {
        inserts.add(sample);
        registerPendingInsert(sample);
        continue;
      }

      final matchIsPending = pendingLocalIds.contains(match.localId);

      final sameUnit = match.unit == sample.unit;
      final sameValue =
          sameUnit && (match.value - sample.value).abs() <= tolerance;
      final sameSource = match.source == sample.source;

      // Values already agree — there is nothing to reconcile and nothing for
      // the user to review, whatever the sources are. This also absorbs a p6.4
      // write-back echo: a row olf pushed out comes back from the platform
      // attributed to that platform, matched by `externalId`, with the value
      // unchanged.
      if (sameValue) {
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
        conflicts.add(
          ReconciliationConflict(
            localId: match.localId,
            local: match,
            incoming: sample,
            reason: ConflictReason.crossSourceDisagreement,
          ),
        );
        continue;
      }

      // p8.6: same non-manual platform, values disagree, and the two readings
      // sit at different precedence tiers — resolve it deterministically, no
      // user prompt. (Tiers: dedicated device > Apple-Watch wrist > bare
      // platform sample; see [sourcePrecedenceTier].)
      final localTier = sourcePrecedenceTier(
        source: match.source,
        isSleepingWrist: match.isSleepingWrist,
        sourceDevice: match.sourceDevice,
      );
      final incomingTier = sourcePrecedenceTier(
        source: sample.source,
        isSleepingWrist: sample.isSleepingWrist,
        sourceDevice: sample.sourceDevice,
      );

      if (localTier != incomingTier) {
        if (incomingTier.outranks(localTier)) {
          if (matchIsPending) {
            // Replace the earlier, lower-tier same-batch insert.
            final loser = pendingSampleByLocalId[match.localId];
            if (loser != null) inserts.remove(loser);
            inserts.add(sample);
            superseded.add(
              ReconciliationSupersede(
                localId: match.localId,
                incoming: loser ?? sample,
              ),
            );
            registerPendingInsert(sample);
          } else {
            updates.add(
              ReconciliationUpdate(localId: match.localId, incoming: sample),
            );
          }
        } else {
          // The stored / earlier reading outranks this one — keep it, drop this.
          superseded.add(
            ReconciliationSupersede(localId: match.localId, incoming: sample),
          );
        }
        continue;
      }

      // p8.2: same tier, but two *different* known devices disagree. olf does
      // not arbitrate — hand it to the user. A device revising *itself*, or a
      // side whose tag olf does not recognise, falls through below.
      final bothDevicesKnown =
          isAttributedDevice(match.sourceDevice) &&
          isAttributedDevice(sample.sourceDevice);
      if (bothDevicesKnown && match.sourceDevice != sample.sourceDevice) {
        conflicts.add(
          ReconciliationConflict(
            localId: match.localId,
            local: match,
            incoming: sample,
            reason: ConflictReason.crossDeviceDisagreement,
          ),
        );
        continue;
      }

      // p8.2: the only thing this sample matched is another insert from this
      // same batch (no stored row), same tier, same/unknown device, values
      // differ. That is exactly the pre-p8.2 "two same-day incoming samples"
      // case — keep both as inserts so the plan shape and the apply-time
      // last-writer-wins behaviour are unchanged for the single-source path.
      if (matchIsPending) {
        inserts.add(sample);
        continue;
      }

      // Same non-manual source, same tier, same-or-unknown device, value
      // revised — safe in-place update.
      updates.add(
        ReconciliationUpdate(localId: match.localId, incoming: sample),
      );
    }

    return ReconciliationPlan(
      inserts: inserts,
      updates: updates,
      conflicts: _foldSameSlotConflicts(conflicts),
      skipped: skipped,
      superseded: superseded,
    );
  }

  /// Fold two or more `crossDeviceDisagreement` conflicts that landed on the
  /// same `(type, day)` into one N-way conflict — the first keeps its `local` /
  /// `incoming`, the rest ride along in [ReconciliationConflict.alsoContending]
  /// (p8.6). Every other conflict, and any slot with a single conflict, is
  /// returned untouched and in its original position.
  static List<ReconciliationConflict> _foldSameSlotConflicts(
    List<ReconciliationConflict> raw,
  ) {
    final bySlot =
        <(HealthSampleType, DateTime), List<ReconciliationConflict>>{};
    for (final c in raw) {
      bySlot
          .putIfAbsent((c.local.type, dateOnly(c.local.day)), () => [])
          .add(c);
    }
    if (bySlot.values.every((g) => g.length < 2)) return raw;

    final out = <ReconciliationConflict>[];
    final emitted = <(HealthSampleType, DateTime)>{};
    for (final c in raw) {
      final key = (c.local.type, dateOnly(c.local.day));
      final group = bySlot[key]!;
      final foldable =
          group.length > 1 &&
          group.every(
            (x) => x.reason == ConflictReason.crossDeviceDisagreement,
          );
      if (!foldable) {
        out.add(c);
        continue;
      }
      if (emitted.add(key)) {
        out.add(
          group.first.withAlsoContending([
            for (final x in group.skip(1)) x.incoming,
          ]),
        );
      }
    }
    return out;
  }

  /// A [LocalSampleView] standing in for an incoming [sample] that is being
  /// inserted this pass, so a later same-`(type, day)` sample can match it
  /// (p8.2). `localId` is synthetic — the caller applies inserts/updates by
  /// day + type, and a `crossDeviceDisagreement` conflict is resolved the same
  /// way — so it only needs to be stable and distinct.
  static LocalSampleView _pendingView(HealthSample sample) {
    final day = dateOnly(sample.day);
    return LocalSampleView(
      localId:
          sample.externalId ??
          'pending:${sample.type.name}:${day.toIso8601String()}',
      type: sample.type,
      day: day,
      value: sample.value,
      unit: sample.unit,
      source: sample.source,
      externalId: sample.externalId,
      sourceDevice: sample.sourceDevice,
      isSleepingWrist: sample.isSleepingWrist,
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
