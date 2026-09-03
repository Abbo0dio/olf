import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';
import 'biometric_providers.dart';
import 'pin_providers.dart';

/// Inactivity auto-lock (p5.3). The deadline maths is `core`'s
/// [nextAutoLockState]; this wires the Settings option, the "is there a lock at
/// all" gate, and the session-local activity clock. `AppGate` owns the timer
/// and the re-lock action.

/// The Settings option set, in minutes. `0` is Off.
const List<int> kAutoLockOptions = <int>[0, 1, 2, 5, 15];

/// Default window (minutes) applied the first time, once a lock exists.
const int kDefaultAutoLockMinutes = 2;

/// Injectable wall clock so the inactivity timer is testable. Overridden in
/// widget tests with a controllable closure.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The timestamp of the last user interaction, session-local (never persisted).
/// `AppGate` bumps it on every pointer-down and whenever the user dismisses the
/// warning; the inactivity timer reads it.
final lastInteractionProvider = StateProvider<DateTime>(
  (ref) => ref.read(nowProvider)(),
);

/// The effective inactivity-lock window in minutes, live.
///
/// `0` (Off) whenever no PIN lock exists — auto-lock is only meaningful behind a
/// lock. Otherwise: the stored value if it is one of [kAutoLockOptions], or
/// [kDefaultAutoLockMinutes] when nothing has been chosen yet.
final autoLockMinutesProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<int>.value(0);

  final lockExists =
      ref.watch(pinCredentialProvider).valueOrNull != null ||
      (ref.watch(biometricUnlockEnabledProvider).valueOrNull ?? false);

  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.autoLockMinutes)
      .map((raw) {
        if (!lockExists) return 0;
        if (raw == null || raw.isEmpty) return kDefaultAutoLockMinutes;
        final n = int.tryParse(raw) ?? 0;
        return kAutoLockOptions.contains(n) ? n : 0;
      });
});

/// Persist the inactivity-lock window (minutes; `0` is Off).
Future<void> setAutoLockMinutes(WidgetRef ref, int minutes) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.autoLockMinutes, minutes.toString());

/// Short label for the picker / Settings trailing text.
String autoLockLabel(int minutes) => switch (minutes) {
  <= 0 => 'Off',
  1 => 'After 1 minute',
  _ => 'After $minutes minutes',
};
