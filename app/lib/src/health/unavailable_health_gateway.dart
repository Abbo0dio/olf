import 'package:olf_core/olf_core.dart';

/// The [HealthPlatformGateway] bound on every platform that has no OS health
/// store olf talks to yet — Android (until p6.3), desktop, web, and the test
/// binding by default.
///
/// Honours the `core` availability contract to the letter: [isAvailable] is
/// `false` and every other method throws [HealthPlatformUnavailable] rather than
/// silently doing nothing. The Settings "Connect Apple Health" tile is hidden
/// whenever this gateway is in effect.
class UnavailableHealthGateway implements HealthPlatformGateway {
  const UnavailableHealthGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<HealthAuthStatus> requestAuthorization(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async => throw const HealthPlatformUnavailable();

  @override
  Future<HealthAuthStatus> authorizationStatus(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async => throw const HealthPlatformUnavailable();

  @override
  Future<List<HealthSample>> read({
    required Set<HealthSampleType> types,
    required DateTime from,
    required DateTime to,
  }) async => throw const HealthPlatformUnavailable();

  @override
  Future<void> write(List<HealthSample> samples) async =>
      throw const HealthPlatformUnavailable();

  @override
  Future<void> delete({
    required HealthSampleType type,
    required DateTime from,
    required DateTime to,
  }) async => throw const HealthPlatformUnavailable();
}
