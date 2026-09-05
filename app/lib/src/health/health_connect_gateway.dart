import 'package:olf_core/olf_core.dart';

import 'health_channel.dart';
import 'health_gateway_base.dart';

/// The Android [HealthPlatformGateway] (p6.3), over the same hand-rolled
/// `olf/health` `MethodChannel` — the Kotlin peer on `MainActivity` mirrors the
/// Swift `HealthKitBridge` and speaks the identical wire contract (it translates
/// Health Connect's menstruation-flow scale to/from the HealthKit wire scale the
/// shared codec expects).
///
/// Bridges the same two types as iOS — [HealthSampleType.menstrualFlow]
/// (Health Connect `MenstruationFlowRecord`) and
/// [HealthSampleType.basalBodyTemperature] (`BasalBodyTemperatureRecord`).
///
/// [isAvailable] is `true` whenever this gateway is *bound* (Android), but
/// Health Connect is an installable system app that may be absent or need an
/// update — so callers gate the Settings tile on the async [runtimeAvailable]
/// probe, and the channel wrapper still turns a missing plugin / native failure
/// into [HealthPlatformUnavailable] as the backstop.
class HealthConnectGateway extends MethodChannelHealthGateway {
  const HealthConnectGateway({HealthChannel channel = const HealthChannel()})
    : super(
        channel,
        platformLabel: 'Health Connect',
        sourceTag: HealthDataSource.healthConnect,
      );

  @override
  bool get isAvailable => true;

  /// Whether the Health Connect SDK is actually reachable on this device
  /// (`HealthConnectClient.getSdkStatus == SDK_AVAILABLE` on the Kotlin side).
  /// `false` when Health Connect is not installed / needs a provider update, or
  /// in any context where the `olf/health` channel is unimplemented.
  Future<bool> runtimeAvailable() => channel.platformAvailable();
}
