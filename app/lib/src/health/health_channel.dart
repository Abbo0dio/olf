import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:olf_core/olf_core.dart';

import 'flow_mapping.dart';

/// The two [HealthSampleType]s the iOS bridge actually maps this slice (p6.2):
/// `menstrualFlow` ↔ `HKCategoryTypeIdentifier.menstrualFlow` and
/// `basalBodyTemperature` ↔ `HKQuantityTypeIdentifier.basalBodyTemperature`.
///
/// The other three model types stay declared on the `core` interface but the
/// bridge has no olf table for them yet — reads come back empty and writes are a
/// no-op, with a logged note.
const Set<HealthSampleType> kIosSupportedHealthTypes = {
  HealthSampleType.menstrualFlow,
  HealthSampleType.basalBodyTemperature,
};

/// Wire token for a [HealthSampleType] on the `olf/health` channel — its enum
/// name, matched on the Swift side.
String healthTypeToken(HealthSampleType type) => type.name;

/// Wire token for a [HealthAccess].
String healthAccessToken(HealthAccess access) => access.name;

/// Parse the status string the Swift side returns (`granted` / `denied` /
/// `notDetermined`). Anything unrecognised is treated as `notDetermined`.
HealthAuthStatus healthAuthStatusFromToken(String? token) {
  for (final s in HealthAuthStatus.values) {
    if (s.name == token) return s;
  }
  return HealthAuthStatus.notDetermined;
}

/// One sample as it crosses the channel — HealthKit-native numbers, no olf
/// semantics. `value` is degrees Celsius for `basalBodyTemperature` and the raw
/// `HKCategoryValueMenstrualFlow` int for `menstrualFlow`.
@immutable
class RawHealthSample {
  const RawHealthSample({
    required this.type,
    required this.startMsEpoch,
    required this.endMsEpoch,
    required this.value,
    this.externalId,
  });

  final HealthSampleType type;
  final int startMsEpoch;
  final int endMsEpoch;
  final double value;
  final String? externalId;

  Map<String, Object?> toWire() => {
    'type': healthTypeToken(type),
    'startMs': startMsEpoch,
    'endMs': endMsEpoch,
    'value': value,
    if (externalId != null) 'externalId': externalId,
  };

  static RawHealthSample? fromWire(Object? entry) {
    if (entry is! Map) return null;
    final typeToken = entry['type'];
    final type = HealthSampleType.values
        .where((t) => t.name == typeToken)
        .firstOrNull;
    final start = (entry['startMs'] as num?)?.toInt();
    final value = (entry['value'] as num?)?.toDouble();
    if (type == null || start == null || value == null) return null;
    final end = (entry['endMs'] as num?)?.toInt() ?? start;
    return RawHealthSample(
      type: type,
      startMsEpoch: start,
      endMsEpoch: end,
      value: value,
      externalId: entry['externalId'] as String?,
    );
  }
}

/// Turn a channel [RawHealthSample] into an olf [HealthSample], applying the
/// unit/scale translation the `core` model expects. Returns `null` when the raw
/// value carries nothing to store (HealthKit "no flow" marker, or a type this
/// build does not map).
HealthSample? healthSampleFromRaw(RawHealthSample raw) {
  final start = DateTime.fromMillisecondsSinceEpoch(raw.startMsEpoch);
  final end = DateTime.fromMillisecondsSinceEpoch(raw.endMsEpoch);
  switch (raw.type) {
    case HealthSampleType.basalBodyTemperature:
      return HealthSample(
        type: HealthSampleType.basalBodyTemperature,
        startAt: start,
        endAt: end,
        value: raw.value,
        unit: HealthUnit.celsius,
        source: HealthDataSource.appleHealth,
        externalId: raw.externalId,
      );
    case HealthSampleType.menstrualFlow:
      final intensity = flowIntensityFromHk(raw.value.round());
      if (intensity == null) return null;
      return HealthSample(
        type: HealthSampleType.menstrualFlow,
        startAt: start,
        endAt: end,
        value: intensity.index.toDouble(),
        unit: HealthUnit.flowLevel,
        source: HealthDataSource.appleHealth,
        externalId: raw.externalId,
      );
    case HealthSampleType.bodyTemperature:
    case HealthSampleType.wristTemperature:
    case HealthSampleType.sleep:
      return null;
  }
}

/// Turn an olf [HealthSample] olf wants written out into a channel
/// [RawHealthSample]. Returns `null` for a type this build does not map (the
/// caller drops it — a silent no-op, per the `core` write contract).
RawHealthSample? rawFromHealthSample(HealthSample sample) {
  if (!kIosSupportedHealthTypes.contains(sample.type)) return null;
  final double wireValue;
  switch (sample.type) {
    case HealthSampleType.basalBodyTemperature:
      wireValue = sample.value;
    case HealthSampleType.menstrualFlow:
      final idx = sample.value.round().clamp(
        0,
        FlowIntensity.values.length - 1,
      );
      wireValue = hkValueFromFlowIntensity(
        FlowIntensity.values[idx],
      ).toDouble();
    case HealthSampleType.bodyTemperature:
    case HealthSampleType.wristTemperature:
    case HealthSampleType.sleep:
      return null;
  }
  return RawHealthSample(
    type: sample.type,
    startMsEpoch: sample.startAt.millisecondsSinceEpoch,
    endMsEpoch: sample.endAt.millisecondsSinceEpoch,
    value: wireValue,
    externalId: sample.externalId,
  );
}

/// Thin wrapper over the hand-rolled `olf/health` `MethodChannel` (Swift on the
/// iOS Runner, the p5.4 `olf/app_icon` pattern). Speaks HealthKit-native
/// numbers; all olf-side scale translation is in the pure codec above so it
/// stays testable without a channel.
///
/// A [MissingPluginException] (desktop, web, the test binding with no mock) or a
/// [PlatformException] from the native side both surface as
/// [HealthPlatformUnavailable] — the caller only ever needs to know "usable or
/// not".
class HealthChannel {
  const HealthChannel();

  static const MethodChannel _channel = MethodChannel('olf/health');

  Future<bool> platformAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('health: isAvailable failed: ${e.code}');
      return false;
    }
  }

  Future<HealthAuthStatus> requestAuthorization(
    Iterable<HealthSampleType> types,
    HealthAccess access,
  ) => _statusCall('requestAuthorization', types, access);

  Future<HealthAuthStatus> authorizationStatus(
    Iterable<HealthSampleType> types,
    HealthAccess access,
  ) => _statusCall('authorizationStatus', types, access);

  Future<HealthAuthStatus> _statusCall(
    String method,
    Iterable<HealthSampleType> types,
    HealthAccess access,
  ) async {
    try {
      final token = await _channel.invokeMethod<String>(method, {
        'types': [for (final t in types) healthTypeToken(t)],
        'access': healthAccessToken(access),
      });
      return healthAuthStatusFromToken(token);
    } on MissingPluginException {
      throw const HealthPlatformUnavailable();
    } on PlatformException catch (e) {
      debugPrint('health: $method failed: ${e.code}');
      throw HealthPlatformUnavailable(e.message ?? e.code);
    }
  }

  Future<List<RawHealthSample>> read(
    Iterable<HealthSampleType> types,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final rows = await _channel.invokeMethod<List<Object?>>('read', {
        'types': [for (final t in types) healthTypeToken(t)],
        'fromMs': from.millisecondsSinceEpoch,
        'toMs': to.millisecondsSinceEpoch,
      });
      if (rows == null) return const [];
      return [
        for (final row in rows)
          if (RawHealthSample.fromWire(row) case final s?) s,
      ];
    } on MissingPluginException {
      throw const HealthPlatformUnavailable();
    } on PlatformException catch (e) {
      debugPrint('health: read failed: ${e.code}');
      throw HealthPlatformUnavailable(e.message ?? e.code);
    }
  }

  Future<void> write(Iterable<RawHealthSample> samples) async {
    try {
      await _channel.invokeMethod<void>('write', {
        'samples': [for (final s in samples) s.toWire()],
      });
    } on MissingPluginException {
      throw const HealthPlatformUnavailable();
    } on PlatformException catch (e) {
      debugPrint('health: write failed: ${e.code}');
      throw HealthPlatformUnavailable(e.message ?? e.code);
    }
  }

  Future<void> delete(HealthSampleType type, DateTime from, DateTime to) async {
    try {
      await _channel.invokeMethod<void>('delete', {
        'type': healthTypeToken(type),
        'fromMs': from.millisecondsSinceEpoch,
        'toMs': to.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      throw const HealthPlatformUnavailable();
    } on PlatformException catch (e) {
      debugPrint('health: delete failed: ${e.code}');
      throw HealthPlatformUnavailable(e.message ?? e.code);
    }
  }
}
