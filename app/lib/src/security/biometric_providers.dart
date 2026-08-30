import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';
import 'biometric_gateway.dart';
import 'local_auth_biometric_gateway.dart';

/// The platform biometric wrapper. Overridden with a fake in tests; the
/// production value never touches a channel until a method is called.
final biometricGatewayProvider = Provider<BiometricGateway>(
  (ref) => LocalAuthBiometricGateway(),
);

/// Whether this device can do a biometric check at all (hardware + enrolment).
/// `false` while loading, so nothing offers biometrics until it resolves true.
final biometricCapableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricGatewayProvider).canAuthenticate(),
);

/// The user's opt-in, from `app_settings`. `false` until the database is open or
/// the user turns it on. Only acted on when a PIN is also set — see
/// [biometricUnlockActiveProvider].
final biometricUnlockEnabledProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.biometricUnlock)
      .map((value) => value == 'true');
});

/// Turn biometric unlock on or off.
Future<void> setBiometricUnlockEnabled(
  WidgetRef ref, {
  required bool enabled,
}) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.biometricUnlock, enabled ? 'true' : 'false');
