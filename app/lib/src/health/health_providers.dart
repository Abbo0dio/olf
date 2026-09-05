import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../flow/flow_providers.dart';
import '../providers.dart';
import '../settings/settings_providers.dart';
import 'health_connect_gateway.dart';
import 'health_import.dart';
import 'healthkit_gateway.dart';
import 'unavailable_health_gateway.dart';

/// The OS health-platform bridge for this build: Apple HealthKit on iOS, Android
/// Health Connect on Android, an [UnavailableHealthGateway] everywhere else
/// (desktop, web, tests). Overridden with a `FakeHealthPlatformGateway` in tests
/// that exercise the connect flow.
final healthPlatformGatewayProvider = Provider<HealthPlatformGateway>((ref) {
  if (kIsWeb) return const UnavailableHealthGateway();
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return const HealthKitGateway();
    case TargetPlatform.android:
      return const HealthConnectGateway();
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return const UnavailableHealthGateway();
  }
});

/// The user-facing name of the OS health platform, for Settings copy —
/// "Apple Health" on iOS, "Health Connect" on Android. Keyed off the platform
/// rather than the bound gateway so it still reads well when a test overrides
/// `healthPlatformGatewayProvider` with a fake.
final healthPlatformNameProvider = Provider<String>((ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'Apple Health';
    case TargetPlatform.android:
      return 'Health Connect';
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return 'your health app';
  }
});

/// Where the user goes to fully revoke olf's access, per platform — shown in the
/// connect / disconnect dialogs.
final healthRevokeHintProvider = Provider<String>((ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'the Health app on your iPhone (Sharing › Apps)';
    case TargetPlatform.android:
      return 'Health Connect on your phone (Manage app permissions)';
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return "your health app's settings";
  }
});

/// Whether the "Apps & export" section should appear at all — `false` hides it.
///
/// A `FutureProvider` because Android needs an async probe: Health Connect may
/// not be installed. iOS / the unavailable gateway answer synchronously.
final healthAvailableProvider = FutureProvider<bool>((ref) async {
  final gateway = ref.watch(healthPlatformGatewayProvider);
  if (gateway is HealthConnectGateway) return gateway.runtimeAvailable();
  return gateway.isAvailable;
});

/// `true` once the user has turned the health bridge on (p6.2), live from
/// `app_settings`. `false` until the database is open or the user connects.
final healthConnectedProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appleHealthConnected)
      .map((value) => value == 'true');
});

/// The most recent sync outcome, live — `null` until the first sync completes.
final healthLastSyncProvider = StreamProvider<HealthSyncSummary?>((ref) {
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
Future<HealthSyncSummary> connectHealthPlatform(WidgetRef ref) async {
  final summary = await ref.read(healthImportServiceProvider).connect();
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await settings.set(SettingKeys.appleHealthLastSync, summary.encode());
  return summary;
}

/// Re-run the sync for an already-connected user and update the stored summary.
Future<HealthSyncSummary> syncHealthPlatform(WidgetRef ref) async {
  final summary = await ref.read(healthImportServiceProvider).sync();
  await ref
      .read(settingsRepositoryProvider)
      .set(SettingKeys.appleHealthLastSync, summary.encode());
  return summary;
}

/// Turn the bridge off. Clears olf's flags only — data already written to each
/// side stays, and OS-level access is revoked separately in the platform's own
/// health settings.
Future<void> disconnectHealthPlatform(WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'false');
  await settings.remove(SettingKeys.appleHealthLastSync);
}
