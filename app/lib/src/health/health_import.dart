import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

/// The plain-language outcome of one health-platform sync, as shown to the user
/// ("added X, updated Y, Z need review") plus when it ran.
@immutable
class HealthSyncSummary {
  const HealthSyncSummary({
    required this.added,
    required this.updated,
    required this.needsReview,
    this.at,
  });

  const HealthSyncSummary.empty()
    : added = 0,
      updated = 0,
      needsReview = 0,
      at = null;

  final int added;
  final int updated;
  final int needsReview;

  /// When the sync completed. `null` for a summary decoded from the pre-p6.4
  /// 3-field storage form (no timestamp was kept then).
  final DateTime? at;

  bool get nothingChanged => added == 0 && updated == 0 && needsReview == 0;

  /// Compact storage form for [SettingKeys.appleHealthLastSync] —
  /// `"a,u,r,<iso8601>"` (p6.4). The timestamp field may be empty.
  String encode() =>
      '$added,$updated,$needsReview,${at?.toIso8601String() ?? ''}';

  /// Parse [encode]'s output. Accepts both the p6.4 4-field form and the
  /// original `"a,u,r"` 3-field form. `null` for anything malformed.
  static HealthSyncSummary? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 3 && parts.length != 4) return null;
    final nums = [for (final p in parts.take(3)) int.tryParse(p.trim())];
    if (nums.any((n) => n == null)) return null;
    DateTime? at;
    if (parts.length == 4 && parts[3].trim().isNotEmpty) {
      at = DateTime.tryParse(parts[3].trim());
      if (at == null) return null;
    }
    return HealthSyncSummary(
      added: nums[0]!,
      updated: nums[1]!,
      needsReview: nums[2]!,
      at: at,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HealthSyncSummary &&
      other.added == added &&
      other.updated == updated &&
      other.needsReview == needsReview &&
      other.at == at;

  @override
  int get hashCode => Object.hash(added, updated, needsReview, at);

  @override
  String toString() =>
      'HealthSyncSummary(added: $added, updated: $updated, '
      'needsReview: $needsReview, at: $at)';
}

/// Everything one sync pass produced: the [summary] counts (persisted, shown on
/// the status surface) and the live [conflicts] the caller stashes for the
/// conflict-review screen (p6.4). Conflicts are never auto-applied.
@immutable
class HealthSyncResult {
  const HealthSyncResult({required this.summary, required this.conflicts});

  final HealthSyncSummary summary;
  final List<ReconciliationConflict> conflicts;
}

/// Runs one import/export pass between the OS health platform and olf's own
/// tables, on top of the pure [ImportReconciler] from `core`.
///
/// Sequence: request read+write authorization → read the last [window] of the
/// two mapped types → reconcile against the local rows → apply the safe inserts
/// and updates → push out the user's own manual rows the platform is missing →
/// return a [HealthSyncResult]. Conflicts are returned, never applied (p6.4's
/// review screen owns them). A `retentionCutoff` (p2.3) drops any sample — in
/// either direction — older than the user's retention window. Nothing here
/// touches the network.
class HealthImportService {
  HealthImportService({
    required HealthPlatformGateway gateway,
    required BbtRepository bbt,
    required DailyFlowRepository flow,
    DateTime Function() now = DateTime.now,
    Duration window = const Duration(days: 180),
    ImportReconciler reconciler = const ImportReconciler(),
  }) : _gateway = gateway,
       _bbt = bbt,
       _flow = flow,
       _now = now,
       _window = window,
       _reconciler = reconciler;

  final HealthPlatformGateway _gateway;
  final BbtRepository _bbt;
  final DailyFlowRepository _flow;
  final DateTime Function() _now;
  final Duration _window;
  final ImportReconciler _reconciler;

  static const Set<HealthSampleType> _types = {
    HealthSampleType.menstrualFlow,
    HealthSampleType.basalBodyTemperature,
    // p8.1a: passive Apple Watch overnight wrist temperature. Read-only — it is
    // never in the write-back set (see [_pushOut]).
    HealthSampleType.wristTemperature,
  };

  /// Ask for authorization and run a full sync. Throws
  /// [HealthPlatformUnavailable] if the platform is not reachable and
  /// [HealthAuthorizationDenied] if the user dismissed the permission sheet
  /// without granting; the caller turns either into a calm message and leaves
  /// the connected flag off.
  Future<HealthSyncResult> connect({DateTime? retentionCutoff}) async {
    final status = await _gateway.requestAuthorization(
      _types,
      access: HealthAccess.readWrite,
    );
    if (status == HealthAuthStatus.denied) {
      throw const HealthAuthorizationDenied();
    }
    return sync(retentionCutoff: retentionCutoff);
  }

  /// Re-run the sync for an already-connected user (no permission prompt).
  ///
  /// [retentionCutoff] is the oldest calendar day the user still keeps (p2.3);
  /// samples before it are neither imported nor written back. `null` keeps
  /// everything.
  Future<HealthSyncResult> sync({DateTime? retentionCutoff}) async {
    final to = _now();
    final windowFrom = to.subtract(_window);
    final from =
        (retentionCutoff != null && retentionCutoff.isAfter(windowFrom))
        ? retentionCutoff
        : windowFrom;

    final rawIncoming = (await _gateway.read(
      types: _types,
      from: from,
      to: to,
    )).where((s) => _inWindow(s.startAt, retentionCutoff)).toList();

    // p8.1a: fold passive Apple Watch wrist-temperature readings into the basal
    // path. They are re-typed to `basalBodyTemperature` *only here*, at the
    // reconcile boundary, so the UNCHANGED `ImportReconciler` makes them compete
    // for the one-row-per-day slot — conflicting against a manual BBT day,
    // updating a prior wrist day. We remember which readings were wrist (by the
    // platform's stable id, which every real HealthKit sample carries) so the
    // row written to `bbt_entries` is tagged `sleepingWrist`, keeping it out of
    // every basal-temperature reader (thermal shift, fertility score, the BBT
    // chart, the doctor report).
    final wristExternalIds = <String>{};
    final wristDaysNoId = <DateTime>{};
    final incoming = <HealthSample>[];
    for (final s in rawIncoming) {
      if (s.type == HealthSampleType.wristTemperature) {
        if (s.externalId != null) {
          wristExternalIds.add(s.externalId!);
        } else {
          wristDaysNoId.add(s.day);
        }
        incoming.add(s.copyWith(type: HealthSampleType.basalBodyTemperature));
      } else {
        incoming.add(s);
      }
    }

    bool isWristReading(HealthSample s) =>
        (s.externalId != null && wristExternalIds.contains(s.externalId)) ||
        (s.externalId == null && wristDaysNoId.contains(s.day));

    final bbtRows = (await _bbt.allEntries())
        .where((r) => _inWindow(r.date, retentionCutoff))
        .toList();
    final flowRows = (await _flow.allFlows())
        .where((r) => _inWindow(r.date, retentionCutoff))
        .toList();
    final local = <LocalSampleView>[
      for (final r in bbtRows)
        LocalSampleView(
          localId: 'bbt:${_isoDay(r.date)}',
          type: HealthSampleType.basalBodyTemperature,
          day: dateOnly(r.date),
          value: r.tempCelsius,
          unit: HealthUnit.celsius,
          source: healthDataSourceFromStorage(r.source),
          externalId: r.externalId,
          // p8.2: so the reconciler can tell an Oura day from a Garmin day.
          sourceDevice: r.sourceDevice,
        ),
      for (final r in flowRows)
        LocalSampleView(
          localId: 'flow:${_isoDay(r.date)}',
          type: HealthSampleType.menstrualFlow,
          day: dateOnly(r.date),
          value: r.intensity.index.toDouble(),
          unit: HealthUnit.flowLevel,
          source: healthDataSourceFromStorage(r.source),
          externalId: r.externalId,
          sourceDevice: r.sourceDevice,
        ),
    ];

    final plan = _reconciler.reconcile(local: local, incoming: incoming);

    for (final sample in plan.inserts) {
      await _apply(sample, asSleepingWrist: isWristReading(sample));
    }
    for (final update in plan.updates) {
      await _apply(
        update.incoming,
        asSleepingWrist: isWristReading(update.incoming),
      );
    }

    // `_pushOut` sees the *raw* incoming (original types) — a wrist reading
    // must not make the platform look like it already holds that day's basal
    // temperature, so a manual BBT on a wrist day still gets seeded outward.
    await _pushOut(incoming: rawIncoming, bbtRows: bbtRows, flowRows: flowRows);

    return HealthSyncResult(
      summary: HealthSyncSummary(
        added: plan.inserts.length,
        updated: plan.updates.length,
        needsReview: plan.conflicts.length,
        at: to,
      ),
      conflicts: plan.conflicts,
    );
  }

  /// `true` when [d]'s calendar day is on or after [cutoff] (or there is no
  /// cutoff). Entries strictly older than the retention cutoff are excluded.
  static bool _inWindow(DateTime d, DateTime? cutoff) =>
      cutoff == null || !dateOnly(d).isBefore(dateOnly(cutoff));

  Future<void> _apply(
    HealthSample sample, {
    bool asSleepingWrist = false,
  }) async {
    // Provenance comes from the sample itself — `appleHealth` from the iOS
    // gateway, `healthConnect` from the Android one (p6.3) — so an imported row
    // records which platform it came from.
    switch (sample.type) {
      case HealthSampleType.basalBodyTemperature:
        await _bbt.setTemp(
          sample.day,
          sample.value,
          source: sample.source,
          externalId: sample.externalId,
          // p8.1a: a re-typed passive wrist reading is stored tagged so it stays
          // out of the basal-temperature readers.
          measurementKind: asSleepingWrist
              ? BbtMeasurementKind.sleepingWrist
              : BbtMeasurementKind.basal,
          // p8.2: carry the originating device onto the stored row.
          sourceDevice: sample.sourceDevice,
        );
      case HealthSampleType.menstrualFlow:
        final idx = sample.value.round().clamp(
          0,
          FlowIntensity.values.length - 1,
        );
        await _flow.setFlow(
          sample.day,
          intensity: FlowIntensity.values[idx],
          source: sample.source,
          externalId: sample.externalId,
          // p8.2: carry the originating device onto the stored row.
          sourceDevice: sample.sourceDevice,
        );
      case HealthSampleType.bodyTemperature:
      case HealthSampleType.wristTemperature:
      case HealthSampleType.sleep:
        break;
    }
  }

  /// Write the user's own manual rows that the platform did not return this
  /// pass out to Health, so a fresh connection seeds Apple Health with what olf
  /// already holds. Best-effort — a write failure is logged, not surfaced, and
  /// never fails the import half.
  Future<void> _pushOut({
    required List<HealthSample> incoming,
    required List<BbtEntry> bbtRows,
    required List<DailyFlow> flowRows,
  }) async {
    final have = {for (final s in incoming) (s.type, dateOnly(s.startAt))};

    final outgoing = <HealthSample>[
      for (final r in bbtRows)
        // p8.1a: only the user's own typed basal readings go out. A passive
        // wrist row is `appleHealth` + `sleepingWrist` — never written back
        // (the Apple Watch owns it); the `measurementKind` check is belt-and-
        // braces alongside the `manual` provenance check.
        if (healthDataSourceFromStorage(r.source) == HealthDataSource.manual &&
            r.measurementKind == BbtMeasurementKind.basal &&
            !have.contains((
              HealthSampleType.basalBodyTemperature,
              dateOnly(r.date),
            )))
          HealthSample.point(
            type: HealthSampleType.basalBodyTemperature,
            at: dateOnly(r.date),
            value: r.tempCelsius,
            unit: HealthUnit.celsius,
            source: HealthDataSource.manual,
          ),
      for (final r in flowRows)
        if (healthDataSourceFromStorage(r.source) == HealthDataSource.manual &&
            !have.contains((HealthSampleType.menstrualFlow, dateOnly(r.date))))
          HealthSample.point(
            type: HealthSampleType.menstrualFlow,
            at: dateOnly(r.date),
            value: r.intensity.index.toDouble(),
            unit: HealthUnit.flowLevel,
            source: HealthDataSource.manual,
          ),
    ];

    if (outgoing.isEmpty) return;
    try {
      await _gateway.write(outgoing);
    } catch (e) {
      debugPrint('health: push-out skipped (${outgoing.length} rows): $e');
    }
  }

  static String _isoDay(DateTime d) {
    final day = dateOnly(d);
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }
}

/// The user reached the OS permission sheet but did not grant it. Distinct from
/// [HealthPlatformUnavailable] (the platform itself is unreachable).
class HealthAuthorizationDenied implements Exception {
  const HealthAuthorizationDenied();

  @override
  String toString() => 'HealthAuthorizationDenied';
}
