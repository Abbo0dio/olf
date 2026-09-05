import 'package:flutter/foundation.dart';
import 'package:olf_core/olf_core.dart';

import 'health_channel.dart';

/// Shared implementation for the two real [HealthPlatformGateway]s — Apple
/// HealthKit (p6.2, iOS) and Android Health Connect (p6.3). Both talk to the
/// same hand-rolled `olf/health` [HealthChannel] with the same wire contract;
/// the only per-platform difference is how [isAvailable] is decided (HealthKit
/// ships on every iPhone; Health Connect is an installable system app), so that
/// stays abstract here.
///
/// Only the two types in [kIosSupportedHealthTypes] cross the bridge on either
/// platform; the other three [HealthSampleType]s are accepted at the API and
/// produce an empty read / a no-op write with a logged note.
abstract class MethodChannelHealthGateway implements HealthPlatformGateway {
  const MethodChannelHealthGateway(
    this.channel, {
    required this.platformLabel,
    required this.sourceTag,
  });

  @protected
  final HealthChannel channel;

  /// Short name for the debug log lines ("iOS", "Health Connect").
  @protected
  final String platformLabel;

  /// Provenance label written onto rows imported through this gateway —
  /// `appleHealth` for iOS, `healthConnect` for Android.
  @protected
  final HealthDataSource sourceTag;

  Set<HealthSampleType> _supported(Set<HealthSampleType> types) {
    final supported = types.intersection(kIosSupportedHealthTypes);
    final skipped = types.difference(kIosSupportedHealthTypes);
    if (skipped.isNotEmpty) {
      debugPrint(
        'health: ignoring ${skipped.map((t) => t.name).join(", ")} — '
        'not mapped on $platformLabel this build',
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
    return channel.requestAuthorization(supported, access);
  }

  @override
  Future<HealthAuthStatus> authorizationStatus(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async {
    final supported = _supported(types);
    if (supported.isEmpty) return HealthAuthStatus.denied;
    return channel.authorizationStatus(supported, access);
  }

  @override
  Future<List<HealthSample>> read({
    required Set<HealthSampleType> types,
    required DateTime from,
    required DateTime to,
  }) async {
    final supported = _supported(types);
    if (supported.isEmpty) return const [];
    final raw = await channel.read(supported, from, to);
    return [
      for (final r in raw)
        if (healthSampleFromRaw(r, source: sourceTag) case final s?) s,
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
    await channel.write(out);
  }

  @override
  Future<void> delete({
    required HealthSampleType type,
    required DateTime from,
    required DateTime to,
  }) async {
    if (!kIosSupportedHealthTypes.contains(type)) {
      debugPrint(
        'health: delete(${type.name}) ignored — not mapped on $platformLabel',
      );
      return;
    }
    await channel.delete(type, from, to);
  }
}
