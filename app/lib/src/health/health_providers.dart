import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../flow/flow_providers.dart';
import '../providers.dart';
import '../retention/retention_providers.dart';
import '../settings/settings_providers.dart';
import 'health_connect_gateway.dart';
import 'health_import.dart';
import 'health_write_back.dart';
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

/// When the last sync ran, live — `null` until the first sync completes.
final healthLastSyncAtProvider = StreamProvider<DateTime?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<DateTime?>.value(null);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appleHealthLastSyncAt)
      .map((raw) => raw == null ? null : DateTime.tryParse(raw));
});

/// The conflicts from the most recent sync, held in memory only (there is no
/// `sync_conflicts` table). The conflict-review screen (p6.4) drains this;
/// disconnecting or a fresh sync replaces it.
final healthConflictsProvider = StateProvider<List<ReconciliationConflict>>(
  (ref) => const [],
);

/// The import/export orchestrator over the current gateway and the BBT / flow
/// repositories, with the p2.3 retention sweep wired in front of every sync.
final healthImportServiceProvider = Provider<HealthImportService>((ref) {
  return HealthImportService(
    gateway: ref.watch(healthPlatformGatewayProvider),
    bbt: ref.watch(bbtRepositoryProvider),
    flow: ref.watch(dailyFlowRepositoryProvider),
    purgeBeforeSync: () => ref.read(retentionControllerProvider).sweepNow(),
    retentionCutoff: () {
      final window =
          ref.read(retentionWindowProvider).valueOrNull ?? RetentionWindow.off;
      return window.cutoff(DateTime.now());
    },
  );
});

/// Pushes single in-app flow / BBT edits out to the platform (p6.4). A no-op
/// [HealthWriteBack.disabled] until a platform is connected.
final healthWriteBackProvider = Provider<HealthWriteBack>((ref) {
  final connected = ref.watch(healthConnectedProvider).valueOrNull ?? false;
  if (!connected) return const HealthWriteBack.disabled();
  return HealthWriteBack(
    gateway: ref.watch(healthPlatformGatewayProvider),
    connected: true,
  );
});

/// Run the opt-in connect: authorize, sync, and — only if that succeeds —
/// persist the connected flag and the summary. Rethrows
/// [HealthPlatformUnavailable] / [HealthAuthorizationDenied] so the caller can
/// show a calm message with nothing persisted.
Future<HealthSyncSummary> connectHealthPlatform(WidgetRef ref) async {
  final result = await ref.read(healthImportServiceProvider).connect();
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await _recordSync(ref, result);
  return result.summary;
}

/// Re-run the sync for an already-connected user and update the stored summary.
Future<HealthSyncSummary> syncHealthPlatform(WidgetRef ref) async {
  final result = await ref.read(healthImportServiceProvider).sync();
  await _recordSync(ref, result);
  return result.summary;
}

/// Persist the counts + timestamp and hand the conflicts to the review screen.
Future<void> _recordSync(WidgetRef ref, HealthSyncResult result) async {
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthLastSync, result.summary.encode());
  await settings.set(
    SettingKeys.appleHealthLastSyncAt,
    DateTime.now().toIso8601String(),
  );
  ref.read(healthConflictsProvider.notifier).state = result.conflicts;
}

HealthSample _sampleFromLocal(ReconciliationConflict c) => HealthSample.point(
  type: c.local.type,
  at: c.local.day,
  value: c.local.value,
  unit: c.local.unit,
  source: HealthDataSource.manual,
);

void _dropConflict(WidgetRef ref, ReconciliationConflict c) {
  final notifier = ref.read(healthConflictsProvider.notifier);
  notifier.state = [
    for (final other in notifier.state)
      if (other != c) other,
  ];
}

/// "Keep mine": push the local value out so the platform agrees, then clear the
/// conflict. Best-effort write — the conflict still clears even if the write
/// fails (the next sync will re-surface it if the platform truly still differs).
Future<void> resolveConflictKeepLocal(
  WidgetRef ref,
  ReconciliationConflict conflict,
) async {
  final gateway = ref.read(healthPlatformGatewayProvider);
  try {
    await gateway.write([_sampleFromLocal(conflict)]);
  } catch (_) {
    // best-effort, same posture as write-back
  }
  _dropConflict(ref, conflict);
}

/// "Use theirs": write the incoming value locally as a manual entry, then clear
/// the conflict.
Future<void> resolveConflictTakeIncoming(
  WidgetRef ref,
  ReconciliationConflict conflict,
) async {
  final incoming = conflict.incoming;
  switch (incoming.type) {
    case HealthSampleType.basalBodyTemperature:
      await ref
          .read(bbtRepositoryProvider)
          .setTemp(incoming.day, incoming.value);
    case HealthSampleType.menstrualFlow:
      final idx = incoming.value.round().clamp(
        0,
        FlowIntensity.values.length - 1,
      );
      await ref
          .read(dailyFlowRepositoryProvider)
          .setFlow(incoming.day, intensity: FlowIntensity.values[idx]);
    case HealthSampleType.bodyTemperature:
    case HealthSampleType.wristTemperature:
    case HealthSampleType.sleep:
      break;
  }
  _dropConflict(ref, conflict);
}

/// "Later": clear the conflict from the list without changing anything. It will
/// re-surface on the next sync if both sides still disagree.
void dismissConflict(WidgetRef ref, ReconciliationConflict conflict) =>
    _dropConflict(ref, conflict);

/// Turn the bridge off. Clears olf's flags only — data already written to each
/// side stays, and OS-level access is revoked separately in the platform's own
/// health settings.
Future<void> disconnectHealthPlatform(WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'false');
  await settings.remove(SettingKeys.appleHealthLastSync);
  await settings.remove(SettingKeys.appleHealthLastSyncAt);
  ref.read(healthConflictsProvider.notifier).state = const [];
}
