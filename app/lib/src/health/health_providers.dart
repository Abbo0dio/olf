import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../flow/flow_providers.dart';
import '../providers.dart';
import '../settings/settings_providers.dart';
import 'healthkit_gateway.dart';
import 'health_import.dart';
import 'unavailable_health_gateway.dart';

/// The OS health-platform bridge for this build: the real Apple HealthKit
/// gateway on iOS, an [UnavailableHealthGateway] everywhere else (Android until
/// p6.3, desktop, web, tests). Overridden with a `FakeHealthPlatformGateway` in
/// tests that exercise the connect flow.
final healthPlatformGatewayProvider = Provider<HealthPlatformGateway>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return const HealthKitGateway();
  }
  return const UnavailableHealthGateway();
});

/// Whether the "Connect Apple Health" tile should appear at all — `false` hides
/// the whole "Apps & export" section.
final healthAvailableProvider = Provider<bool>(
  (ref) => ref.watch(healthPlatformGatewayProvider).isAvailable,
);

/// `true` once the user has turned the Apple Health bridge on (p6.2), live from
/// `app_settings`. `false` until the database is open or the user connects.
final appleHealthConnectedProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appleHealthConnected)
      .map((value) => value == 'true');
});

/// The most recent sync outcome, live — `null` until the first sync completes.
final appleHealthLastSyncProvider = StreamProvider<HealthSyncSummary?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<HealthSyncSummary?>.value(null);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appleHealthLastSync)
      .map(HealthSyncSummary.decode);
});

/// The import/export orchestrator over the current gateway and the BBT / flow
/// repositories.
final healthImportServiceProvider = Provider<HealthImportService>((ref) {
  return HealthImportService(
    gateway: ref.watch(healthPlatformGatewayProvider),
    bbt: ref.watch(bbtRepositoryProvider),
    flow: ref.watch(dailyFlowRepositoryProvider),
  );
});

/// Run the opt-in connect: authorize, sync, and — only if that succeeds —
/// persist the connected flag and the summary. Rethrows
/// [HealthPlatformUnavailable] / [HealthAuthorizationDenied] so the caller can
/// show a calm message with nothing persisted.
Future<HealthSyncSummary> connectAppleHealth(WidgetRef ref) async {
  final summary = await ref.read(healthImportServiceProvider).connect();
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await settings.set(SettingKeys.appleHealthLastSync, summary.encode());
  return summary;
}

/// Re-run the sync for an already-connected user and update the stored summary.
Future<HealthSyncSummary> syncAppleHealth(WidgetRef ref) async {
  final summary = await ref.read(healthImportServiceProvider).sync();
  await ref
      .read(settingsRepositoryProvider)
      .set(SettingKeys.appleHealthLastSync, summary.encode());
  return summary;
}

/// Turn the bridge off. Clears olf's flags only — data already written to each
/// side stays, and iOS access is revoked separately in the system Health app.
Future<void> disconnectAppleHealth(WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'false');
  await settings.remove(SettingKeys.appleHealthLastSync);
}
