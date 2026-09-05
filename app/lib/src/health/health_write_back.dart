import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

import 'unavailable_health_gateway.dart';

/// Pushes a single in-app flow / BBT edit out to the connected health platform
/// (p6.4). A thin, best-effort call from the logging widgets — no queue, no
/// retry, same posture as [HealthImportService]'s `_pushOut`: a failure is
/// logged and swallowed, never surfaced.
///
/// Rows written here always carry `source: manual` and no `externalId` (any
/// in-app edit already flipped the row to manual and cleared its external id in
/// p6.2). On the next sync the platform returns them value-equal, so the
/// [ImportReconciler] skips them — no duplicate. A genuine later disagreement
/// (e.g. the platform still holds an older value from another app) surfaces in
/// the conflict-review screen, which is the intended place to resolve it.
class HealthWriteBack {
  const HealthWriteBack({
    required HealthPlatformGateway gateway,
    required bool connected,
  }) : _gateway = gateway,
       _connected = connected;

  /// A no-op instance for when nothing is connected — every method returns
  /// immediately.
  const HealthWriteBack.disabled()
    : _gateway = const UnavailableHealthGateway(),
      _connected = false;

  final HealthPlatformGateway _gateway;
  final bool _connected;

  bool get _on => _connected && _gateway.isAvailable;

  /// The user set or changed today's flow — write the current value out.
  Future<void> flowLogged(DateTime day, {required FlowIntensity intensity}) =>
      _write(
        HealthSample.point(
          type: HealthSampleType.menstrualFlow,
          at: dateOnly(day),
          value: intensity.index.toDouble(),
          unit: HealthUnit.flowLevel,
          source: HealthDataSource.manual,
        ),
      );

  /// The user cleared today's flow — remove olf's record for that day.
  Future<void> flowCleared(DateTime day) =>
      _delete(HealthSampleType.menstrualFlow, day);

  /// The user set or changed today's basal temperature — write it out.
  Future<void> bbtLogged(DateTime day, {required double celsius}) => _write(
    HealthSample.point(
      type: HealthSampleType.basalBodyTemperature,
      at: dateOnly(day),
      value: celsius,
      unit: HealthUnit.celsius,
      source: HealthDataSource.manual,
    ),
  );

  /// The user cleared today's basal temperature.
  Future<void> bbtCleared(DateTime day) =>
      _delete(HealthSampleType.basalBodyTemperature, day);

  Future<void> _write(HealthSample sample) async {
    if (!_on) return;
    try {
      await _gateway.write([sample]);
    } catch (e) {
      debugPrint('health: write-back (${sample.type.name}) skipped: $e');
    }
  }

  Future<void> _delete(HealthSampleType type, DateTime day) async {
    if (!_on) return;
    // olf's flow / BBT rows are day-keyed at local midnight, so a from..to of
    // exactly that day removes olf's record without reaching the next day's
    // midnight sample (the gateway's range is inclusive on both ends).
    final start = dateOnly(day);
    try {
      await _gateway.delete(type: type, from: start, to: start);
    } catch (e) {
      debugPrint('health: write-back delete (${type.name}) skipped: $e');
    }
  }
}
