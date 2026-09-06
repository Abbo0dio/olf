import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_providers.dart';
import '../pregnancy/pregnancy_providers.dart';
import '../providers.dart';
import '../settings/settings_providers.dart';

/// Whether a given Phase 7 [LifeStageMode] is turned on, live from the
/// `app_settings` KV store (p7.1). `false` until the database is open or the
/// user turns it on — every mode is off by default.
final lifeStageModeEnabledProvider = StreamProvider.family<bool, LifeStageMode>(
  (ref, mode) {
    final db = ref.watch(appDatabaseProvider);
    if (db is! AsyncData) return Stream<bool>.value(false);
    return ref
        .watch(settingsRepositoryProvider)
        .watch(mode.settingKey)
        .map(lifeStageModeEnabled);
  },
);

/// Turn [mode] on or off. Turning a mode off only clears its flag — no logged
/// data is touched.
Future<void> setLifeStageModeEnabled(
  WidgetRef ref,
  LifeStageMode mode, {
  required bool enabled,
}) => ref
    .read(settingsRepositoryProvider)
    .set(mode.settingKey, lifeStageModeValue(enabled: enabled));

/// The postpartum cycle-return view derived from the recorded pregnancy
/// loss / birth and the periods logged since (p7.1). `null` when nothing is
/// recorded. Pure `core` derivation; `DateTime.now()` is read at this edge,
/// matching `prediction_providers`.
final postpartumCycleReturnProvider = Provider<PostpartumCycleReturn?>((ref) {
  final events =
      ref.watch(pregnancyEventsProvider).value ?? const <PregnancyEvent>[];
  final periods = ref.watch(periodsProvider).value ?? const <Period>[];
  return derivePostpartumCycleReturn(
    events: events,
    periods: periods,
    today: DateTime.now(),
  );
});
