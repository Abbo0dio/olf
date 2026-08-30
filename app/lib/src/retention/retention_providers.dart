import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// The auto-deletion engine over the open database. Only valid inside the
/// database `data` branch (see [appDatabaseProvider]).
final retentionServiceProvider = Provider<RetentionService>(
  (ref) => RetentionService(ref.watch(appDatabaseProvider).requireValue),
);

/// The chosen retention window, live from `app_settings`. `off` until the
/// database is open or the user chooses otherwise.
final retentionWindowProvider = StreamProvider<RetentionWindow>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) {
    return Stream<RetentionWindow>.value(RetentionWindow.off);
  }
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.retentionWindow)
      .map(RetentionWindow.fromStorage);
});

/// Reads the window and drives [RetentionService].
final retentionControllerProvider = Provider<RetentionController>(
  (ref) => RetentionController(
    ref.watch(retentionServiceProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

/// Runs one sweep when the app reaches the home screen with a window set. Guards
/// on the **real** vault so a decoy session never purges anything, and re-runs
/// if the window changes (harmless — the sweep is idempotent).
final retentionStartupSweepProvider = FutureProvider<RetentionSweepResult>((
  ref,
) async {
  if (ref.watch(appVaultProvider) != AppVault.real) {
    return const RetentionSweepResult.none();
  }
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return const RetentionSweepResult.none();
  final window = await ref.watch(retentionWindowProvider.future);
  if (window == RetentionWindow.off) return const RetentionSweepResult.none();
  return ref.read(retentionControllerProvider).sweepNow(window: window);
});

/// Applies a retention window and keeps the stored setting and the data in step.
class RetentionController {
  RetentionController(this._service, this._settings);

  final RetentionService _service;
  final SettingsRepository _settings;

  /// Persist [window] and immediately purge anything it now excludes.
  Future<RetentionSweepResult> setWindow(RetentionWindow window) async {
    await _settings.set(SettingKeys.retentionWindow, window.storageToken);
    return _sweep(window);
  }

  /// Sweep with the current (or supplied) window. Used on launch and before a
  /// backup export.
  Future<RetentionSweepResult> sweepNow({RetentionWindow? window}) async {
    final w =
        window ??
        RetentionWindow.fromStorage(
          await _settings.get(SettingKeys.retentionWindow),
        );
    return _sweep(w);
  }

  Future<RetentionSweepResult> _sweep(RetentionWindow window) async {
    final result = await _service.sweep(now: DateTime.now(), window: window);
    if (result.didAnything) {
      final on = result.cutoff!.toIso8601String().split('T').first;
      // Count + a date threshold only — no entry content (§3: no PHI in logs).
      debugPrint(
        'retention: purged ${result.total} entr'
        '${result.total == 1 ? 'y' : 'ies'} older than $on',
      );
    }
    return result;
  }
}
