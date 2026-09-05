import 'package:olf_core/olf_core.dart';

import 'health_channel.dart';
import 'health_gateway_base.dart';

/// The iOS [HealthPlatformGateway] (p6.2), over the hand-rolled `olf/health`
/// `MethodChannel`.
///
/// Bridges exactly the two types HealthKit and olf have in common —
/// [HealthSampleType.menstrualFlow] and
/// [HealthSampleType.basalBodyTemperature] (see [MethodChannelHealthGateway]).
///
/// [isAvailable] is `true` on every build where this gateway is bound (iOS —
/// HealthKit ships on every iPhone olf's floor supports). The
/// availability-race backstop in the `core` contract is still honoured: the
/// channel wrapper turns a missing plugin or a native failure into
/// [HealthPlatformUnavailable].
class HealthKitGateway extends MethodChannelHealthGateway {
  const HealthKitGateway({HealthChannel channel = const HealthChannel()})
    : super(
        channel,
        platformLabel: 'iOS',
        sourceTag: HealthDataSource.appleHealth,
      );

  @override
  bool get isAvailable => true;
}
