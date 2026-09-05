import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

/// The plain-language outcome of one Apple Health sync, as shown to the user
/// ("added X, updated Y, Z need review").
@immutable
class HealthSyncSummary {
  const HealthSyncSummary({
    required this.added,
    required this.updated,
    required this.needsReview,
  });

  const HealthSyncSummary.empty() : added = 0, updated = 0, needsReview = 0;

  final int added;
  final int updated;
  final int needsReview;

  bool get nothingChanged => added == 0 && updated == 0 && needsReview == 0;

  /// Compact storage form for [SettingKeys.appleHealthLastSync] — `"a,u,r"`.
  String encode() => '$added,$updated,$needsReview';

  /// Parse [encode]'s output. `null` for anything malformed.
  static HealthSyncSummary? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 3) return null;
    final nums = [for (final p in parts) int.tryParse(p.trim())];
    if (nums.any((n) => n == null)) return null;
    return HealthSyncSummary(
      added: nums[0]!,
      updated: nums[1]!,
      needsReview: nums[2]!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HealthSyncSummary &&
      other.added == added &&
      other.updated == updated &&
      other.needsReview == needsReview;

  @override
  int get hashCode => Object.hash(added, updated, needsReview);

  @override
  String toString() =>
      'HealthSyncSummary(added: $added, updated: $updated, '
      'needsReview: $needsReview)';
}

/// Runs one import/export pass between the OS health platform and olf's own
/// tables, on top of the pure [ImportReconciler] from `core`.
///
/// Sequence: request read+write authorization → read the last [window] of the
/// two mapped types → reconcile against the local rows → apply the safe inserts
/// and updates → push out the user's own manual rows the platform is missing →
/// return a [HealthSyncSummary]. Conflicts are counted, never applied (p6.4
/// owns the review screen). Nothing here touches the network.
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
  };

  /// Ask for authorization and run a full sync. Throws
  /// [HealthPlatformUnavailable] if the platform is not reachable and
  /// [HealthAuthorizationDenied] if the user dismissed the permission sheet
  /// without granting; the caller turns either into a calm message and leaves
  /// the connected flag off.
  Future<HealthSyncSummary> connect() async {
    final status = await _gateway.requestAuthorization(
      _types,
      access: HealthAccess.readWrite,
    );
    if (status == HealthAuthStatus.denied) {
      throw const HealthAuthorizationDenied();
    }
    return sync();
  }

  /// Re-run the sync for an already-connected user (no permission prompt).
  Future<HealthSyncSummary> sync() async {
    final to = _now();
    final from = to.subtract(_window);

    final incoming = await _gateway.read(types: _types, from: from, to: to);

    final bbtRows = await _bbt.allEntries();
    final flowRows = await _flow.allFlows();
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
        ),
    ];

    final plan = _reconciler.reconcile(local: local, incoming: incoming);

    for (final sample in plan.inserts) {
      await _apply(sample);
    }
    for (final update in plan.updates) {
      await _apply(update.incoming);
    }

    await _pushOut(incoming: incoming, bbtRows: bbtRows, flowRows: flowRows);

    return HealthSyncSummary(
      added: plan.inserts.length,
      updated: plan.updates.length,
      needsReview: plan.conflicts.length,
    );
  }

  Future<void> _apply(HealthSample sample) async {
    switch (sample.type) {
      case HealthSampleType.basalBodyTemperature:
        await _bbt.setTemp(
          sample.day,
          sample.value,
          source: HealthDataSource.appleHealth,
          externalId: sample.externalId,
        );
      case HealthSampleType.menstrualFlow:
        final idx = sample.value.round().clamp(
          0,
          FlowIntensity.values.length - 1,
        );
        await _flow.setFlow(
          sample.day,
          intensity: FlowIntensity.values[idx],
          source: HealthDataSource.appleHealth,
          externalId: sample.externalId,
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
        if (healthDataSourceFromStorage(r.source) == HealthDataSource.manual &&
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
