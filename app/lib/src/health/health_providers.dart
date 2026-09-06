import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_providers.dart';
import '../flow/flow_providers.dart';
import '../providers.dart';
import '../retention/retention_providers.dart';
import '../settings/settings_providers.dart';
import 'device_label.dart';
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

/// How many passively-captured Apple Watch wrist-temperature readings olf holds
/// (p8.1a), live from the BBT stream. Drives the per-source status line under
/// the health tile in Settings. `0` until the stream has data.
final passiveWristTempCountProvider = Provider<int>((ref) {
  final entries = ref.watch(bbtEntriesProvider).valueOrNull ?? const [];
  return entries
      .where((e) => e.measurementKind == BbtMeasurementKind.sleepingWrist)
      .length;
});

/// One device / app that has contributed at least one imported reading olf
/// still holds (schema v11, p8.2), for the per-device status list in Settings.
@immutable
class ContributingDevice {
  const ContributingDevice({
    required this.rawTag,
    required this.label,
    required this.readingCount,
    required this.lastDay,
  });

  /// The stored `source_device` string, verbatim.
  final String rawTag;

  /// [rawTag] run through [prettyDeviceLabel] for display.
  final String label;

  /// How many stored rows (BBT + flow) carry this exact tag.
  final int readingCount;

  /// The most recent calendar day a row with this tag is for.
  final DateTime lastDay;

  @override
  bool operator ==(Object other) =>
      other is ContributingDevice &&
      other.rawTag == rawTag &&
      other.label == label &&
      other.readingCount == readingCount &&
      other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(rawTag, label, readingCount, lastDay);
}

/// The devices / apps behind the imported readings olf currently holds, most
/// recently seen first (schema v11, p8.2). Derived live from the BBT + flow
/// streams; rows with no `source_device` (manual, legacy, unattributed) are
/// ignored, so an all-manual database yields an empty list and the Settings
/// section stays hidden.
final contributingDevicesProvider = Provider<List<ContributingDevice>>((ref) {
  final bbt = ref.watch(bbtEntriesProvider).valueOrNull ?? const [];
  final flows = ref.watch(dailyFlowsProvider).valueOrNull ?? const [];

  final counts = <String, int>{};
  final lastDay = <String, DateTime>{};
  void tally(String? tag, DateTime day) {
    final key = tag?.trim();
    if (key == null || key.isEmpty) return;
    counts[key] = (counts[key] ?? 0) + 1;
    final prev = lastDay[key];
    if (prev == null || day.isAfter(prev)) lastDay[key] = day;
  }

  for (final e in bbt) {
    tally(e.sourceDevice, e.date);
  }
  for (final f in flows) {
    tally(f.sourceDevice, f.date);
  }

  final devices =
      [
        for (final entry in counts.entries)
          ContributingDevice(
            rawTag: entry.key,
            label: prettyDeviceLabel(entry.key) ?? entry.key,
            readingCount: entry.value,
            lastDay: lastDay[entry.key]!,
          ),
      ]..sort((a, b) {
        final byRecency = b.lastDay.compareTo(a.lastDay);
        if (byRecency != 0) return byRecency;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
  return List.unmodifiable(devices);
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

/// Pushes a single app-entered flow / BBT day out to the connected platform
/// (p6.4). Used by the log sheets and by "keep mine" on the conflict-review
/// screen.
final healthWriteBackProvider = Provider<HealthWriteBack>((ref) {
  return HealthWriteBack(
    gateway: ref.watch(healthPlatformGatewayProvider),
    bbt: ref.watch(bbtRepositoryProvider),
    flow: ref.watch(dailyFlowRepositoryProvider),
  );
});

/// The unresolved conflicts from the most recent sync (p6.4), held in memory
/// for the conflict-review screen. Re-derived on the next sync; not persisted
/// across an app restart.
final healthConflictsProvider =
    NotifierProvider<HealthConflictsNotifier, List<ReconciliationConflict>>(
      HealthConflictsNotifier.new,
    );

class HealthConflictsNotifier extends Notifier<List<ReconciliationConflict>> {
  @override
  List<ReconciliationConflict> build() => const [];

  void replaceWith(List<ReconciliationConflict> conflicts) =>
      state = List.unmodifiable(conflicts);

  void resolve(ReconciliationConflict conflict) =>
      state = List.unmodifiable(state.where((c) => c != conflict));
}

/// The oldest calendar day the user still keeps, from the live retention
/// window. `null` when auto-delete is off.
DateTime? _retentionCutoff(WidgetRef ref) {
  final window =
      ref.read(retentionWindowProvider).valueOrNull ?? RetentionWindow.off;
  return window.cutoff(DateTime.now());
}

/// Run the opt-in connect: purge anything outside the retention window,
/// authorize, sync, and — only if that succeeds — persist the connected flag,
/// the summary and any conflicts. Rethrows [HealthPlatformUnavailable] /
/// [HealthAuthorizationDenied] so the caller can show a calm message with
/// nothing persisted.
Future<HealthSyncSummary> connectHealthPlatform(WidgetRef ref) async {
  await ref.read(retentionControllerProvider).sweepNow();
  final result = await ref
      .read(healthImportServiceProvider)
      .connect(retentionCutoff: _retentionCutoff(ref));
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await settings.set(SettingKeys.appleHealthLastSync, result.summary.encode());
  ref.read(healthConflictsProvider.notifier).replaceWith(result.conflicts);
  return result.summary;
}

/// Re-run the sync for an already-connected user: purge-before-sync, then
/// update the stored summary and the in-memory conflict list.
Future<HealthSyncSummary> syncHealthPlatform(WidgetRef ref) async {
  await ref.read(retentionControllerProvider).sweepNow();
  final result = await ref
      .read(healthImportServiceProvider)
      .sync(retentionCutoff: _retentionCutoff(ref));
  await ref
      .read(settingsRepositoryProvider)
      .set(SettingKeys.appleHealthLastSync, result.summary.encode());
  ref.read(healthConflictsProvider.notifier).replaceWith(result.conflicts);
  return result.summary;
}

/// Turn the bridge off. Clears olf's flags only — data already written to each
/// side stays, and OS-level access is revoked separately in the platform's own
/// health settings.
Future<void> disconnectHealthPlatform(WidgetRef ref) async {
  final settings = ref.read(settingsRepositoryProvider);
  await settings.set(SettingKeys.appleHealthConnected, 'false');
  await settings.remove(SettingKeys.appleHealthLastSync);
  ref.read(healthConflictsProvider.notifier).replaceWith(const []);
}

/// Push the current app-entered value for [day] out to the connected platform,
/// if one is connected. Fire-and-forget from a log sheet; never throws.
Future<void> writeBackBbt(WidgetRef ref, DateTime day) async {
  if (!(ref.read(healthConnectedProvider).valueOrNull ?? false)) return;
  await ref
      .read(healthWriteBackProvider)
      .bbt(day, retentionCutoff: _retentionCutoff(ref));
}

Future<void> writeBackFlow(WidgetRef ref, DateTime day) async {
  if (!(ref.read(healthConnectedProvider).valueOrNull ?? false)) return;
  await ref
      .read(healthWriteBackProvider)
      .flow(day, retentionCutoff: _retentionCutoff(ref));
}

/// How the user resolved one conflict on the review screen (p6.4).
enum ConflictResolution {
  /// The app-entered value wins — write it back out so the platform agrees.
  keepLocal,

  /// The platform value wins — store it locally as a manual entry.
  takeIncoming,

  /// Leave both sides as they are for now (it reappears on the next sync).
  dismiss,
}

/// Apply [how] to [conflict] and drop it from [healthConflictsProvider]. Each
/// path is an ordinary repository / gateway write, so the outcome is a plain
/// stored value — nothing conflict-specific is persisted.
Future<void> resolveHealthConflict(
  WidgetRef ref,
  ReconciliationConflict conflict,
  ConflictResolution how,
) async {
  switch (how) {
    case ConflictResolution.keepLocal:
      final day = conflict.local.day;
      switch (conflict.local.type) {
        case HealthSampleType.basalBodyTemperature:
          await writeBackBbt(ref, day);
        case HealthSampleType.menstrualFlow:
          await writeBackFlow(ref, day);
        case HealthSampleType.bodyTemperature:
        case HealthSampleType.wristTemperature:
        case HealthSampleType.sleep:
          break;
      }
    case ConflictResolution.takeIncoming:
      final s = conflict.incoming;
      switch (s.type) {
        case HealthSampleType.basalBodyTemperature:
          // SHORTCUT: a passive Apple Watch wrist reading is re-typed to
          // `basalBodyTemperature` before reconciliation (p8.1a), so a
          // wrist-vs-manual-BBT conflict resolved "take incoming" here stores
          // it as a basal temperature — the pure `ReconciliationConflict` does
          // not carry the measurement kind. Rare manual action; the row can be
          // re-corrected in the day sheet. A cleaner fix (kind on the conflict)
          // waits for p8.5's richer multi-source model.
          await ref
              .read(bbtRepositoryProvider)
              .setTemp(s.day, s.value, externalId: s.externalId);
        case HealthSampleType.menstrualFlow:
          final idx = s.value.round().clamp(0, FlowIntensity.values.length - 1);
          await ref
              .read(dailyFlowRepositoryProvider)
              .setFlow(
                s.day,
                intensity: FlowIntensity.values[idx],
                externalId: s.externalId,
              );
        case HealthSampleType.bodyTemperature:
        case HealthSampleType.wristTemperature:
        case HealthSampleType.sleep:
          break;
      }
    case ConflictResolution.dismiss:
      break;
  }
  ref.read(healthConflictsProvider.notifier).resolve(conflict);
}
