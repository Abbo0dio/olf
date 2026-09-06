import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

/// Pushes a single app-entered flow / BBT day back out to the connected OS
/// health platform (p6.4).
///
/// Called right after a successful local `setFlow` / `setTemp`. It reads the
/// stored row back so it always sends exactly what olf now holds — including
/// the `externalId`, which the repositories keep sticky across an edit, so a
/// previously-imported day updates its platform record in place instead of
/// creating a duplicate.
///
/// Best-effort and non-blocking: a write-back failure (platform unreachable,
/// permission revoked) is logged and swallowed — it never fails or delays the
/// log the user just made. The caller is responsible for only invoking this
/// when a platform is actually connected.
class HealthWriteBack {
  HealthWriteBack({
    required HealthPlatformGateway gateway,
    required BbtRepository bbt,
    required DailyFlowRepository flow,
  }) : _gateway = gateway,
       _bbt = bbt,
       _flow = flow;

  final HealthPlatformGateway _gateway;
  final BbtRepository _bbt;
  final DailyFlowRepository _flow;

  /// Write the stored basal temperature for [day] out to the platform. A no-op
  /// when the day has no row (e.g. it was just cleared) or is older than
  /// [retentionCutoff] (p2.3 — never write back data the user no longer keeps).
  Future<void> bbt(DateTime day, {DateTime? retentionCutoff}) async {
    if (_excluded(day, retentionCutoff)) return;
    final row = await _bbt.tempOn(day);
    if (row == null) return;
    await _push(
      HealthSample.point(
        type: HealthSampleType.basalBodyTemperature,
        at: dateOnly(day),
        value: row.tempCelsius,
        unit: HealthUnit.celsius,
        source: healthDataSourceFromStorage(row.source),
        externalId: row.externalId,
      ),
    );
  }

  /// Write the stored flow for [day] out to the platform. Same no-op rules as
  /// [bbt].
  Future<void> flow(DateTime day, {DateTime? retentionCutoff}) async {
    if (_excluded(day, retentionCutoff)) return;
    final row = await _flow.flowOn(day);
    if (row == null) return;
    await _push(
      HealthSample.point(
        type: HealthSampleType.menstrualFlow,
        at: dateOnly(day),
        value: row.intensity.index.toDouble(),
        unit: HealthUnit.flowLevel,
        source: healthDataSourceFromStorage(row.source),
        externalId: row.externalId,
      ),
    );
  }

  Future<void> _push(HealthSample sample) async {
    try {
      await _gateway.write([sample]);
    } catch (e) {
      // No PHI — the type name and the error only (§3: nothing sensitive in
      // logs).
      debugPrint('health: write-back skipped (${sample.type.name}): $e');
    }
  }

  bool _excluded(DateTime day, DateTime? cutoff) =>
      cutoff != null && dateOnly(day).isBefore(dateOnly(cutoff));
}
