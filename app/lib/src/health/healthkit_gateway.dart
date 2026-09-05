import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

import 'health_channel.dart';

/// The iOS [HealthPlatformGateway] (p6.2), over the hand-rolled `olf/health`
/// `MethodChannel`.
///
/// Bridges exactly the two types HealthKit and olf have in common —
/// [HealthSampleType.menstrualFlow] and
/// [HealthSampleType.basalBodyTemperature]. The other three model types are
/// accepted at the API but produce an empty read / a no-op write and a logged
/// note; olf has no table for them yet.
///
/// [isAvailable] is `true` on every build where this gateway is bound (iOS —
/// HealthKit ships on every iPhone olf's floor supports). The
/// availability-race backstop in the `core` contract is still honoured: the
/// channel wrapper turns a missing plugin or a native failure into
/// [HealthPlatformUnavailable].
class HealthKitGateway implements HealthPlatformGateway {
  const HealthKitGateway({HealthChannel channel = const HealthChannel()})
    : _channel = channel;

  final HealthChannel _channel;

  @override
  bool get isAvailable => true;

  Set<HealthSampleType> _supported(Set<HealthSampleType> types) {
    final supported = types.intersection(kIosSupportedHealthTypes);
    final skipped = types.difference(kIosSupportedHealthTypes);
    if (skipped.isNotEmpty) {
      debugPrint(
        'health: ignoring ${skipped.map((t) => t.name).join(", ")} — '
        'not mapped on iOS this build',
      );
    }
    return supported;
  }

  @override
  Future<HealthAuthStatus> requestAuthorization(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async {
    final supported = _supported(types);
    if (supported.isEmpty) return HealthAuthStatus.denied;
    return _channel.requestAuthorization(supported, access);
  }

  @override
  Future<HealthAuthStatus> authorizationStatus(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async {
    final supported = _supported(types);
    if (supported.isEmpty) return HealthAuthStatus.denied;
    return _channel.authorizationStatus(supported, access);
  }

  @override
  Future<List<HealthSample>> read({
    required Set<HealthSampleType> types,
    required DateTime from,
    required DateTime to,
  }) async {
    final supported = _supported(types);
    if (supported.isEmpty) return const [];
    final raw = await _channel.read(supported, from, to);
    return [
      for (final r in raw)
        if (healthSampleFromRaw(r) case final s?) s,
    ];
  }

  @override
  Future<void> write(List<HealthSample> samples) async {
    final out = [
      for (final s in samples)
        if (rawFromHealthSample(s) case final r?) r,
    ];
    final dropped = samples.length - out.length;
    if (dropped > 0) {
      debugPrint('health: skipped $dropped unmapped sample(s) on write');
    }
    if (out.isEmpty) return;
    await _channel.write(out);
  }

  @override
  Future<void> delete({
    required HealthSampleType type,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!kIosSupportedHealthTypes.contains(type)) {
      debugPrint('health: delete(${type.name}) ignored — not mapped on iOS');
      return;
    }
    await _channel.delete(type, from, to);
  }
}
