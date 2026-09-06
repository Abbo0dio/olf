import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_core/olf_core.dart';

/// A [HealthConflictsNotifier] pre-seeded with [seed], for
/// `healthConflictsProvider.overrideWith(seededConflicts([...]))` in tests.
HealthConflictsNotifier Function() seededConflicts(
  List<ReconciliationConflict> seed,
) =>
    () => _SeededConflicts(seed);

class _SeededConflicts extends HealthConflictsNotifier {
  _SeededConflicts(this._seed);
  final List<ReconciliationConflict> _seed;
  @override
  List<ReconciliationConflict> build() => List.unmodifiable(_seed);
}

ReconciliationConflict bbtConflict(
  DateTime day, {
  required double local,
  required double incoming,
  String? externalId,
}) {
  final d = DateTime(day.year, day.month, day.day);
  return ReconciliationConflict(
    localId: 'bbt:${d.toIso8601String()}',
    local: LocalSampleView(
      localId: 'bbt:${d.toIso8601String()}',
      type: HealthSampleType.basalBodyTemperature,
      day: d,
      value: local,
      unit: HealthUnit.celsius,
      source: HealthDataSource.manual,
      externalId: externalId,
    ),
    incoming: HealthSample.point(
      type: HealthSampleType.basalBodyTemperature,
      at: d,
      value: incoming,
      unit: HealthUnit.celsius,
      source: HealthDataSource.appleHealth,
      externalId: externalId ?? 'hk-${d.toIso8601String()}',
    ),
    reason: ConflictReason.manualDisagreement,
  );
}

ReconciliationConflict flowConflict(
  DateTime day, {
  required FlowIntensity local,
  required FlowIntensity incoming,
  String? externalId,
}) {
  final d = DateTime(day.year, day.month, day.day);
  return ReconciliationConflict(
    localId: 'flow:${d.toIso8601String()}',
    local: LocalSampleView(
      localId: 'flow:${d.toIso8601String()}',
      type: HealthSampleType.menstrualFlow,
      day: d,
      value: local.index.toDouble(),
      unit: HealthUnit.flowLevel,
      source: HealthDataSource.manual,
      externalId: externalId,
    ),
    incoming: HealthSample.point(
      type: HealthSampleType.menstrualFlow,
      at: d,
      value: incoming.index.toDouble(),
      unit: HealthUnit.flowLevel,
      source: HealthDataSource.appleHealth,
      externalId: externalId ?? 'hk-${d.toIso8601String()}',
    ),
    reason: ConflictReason.manualDisagreement,
  );
}
