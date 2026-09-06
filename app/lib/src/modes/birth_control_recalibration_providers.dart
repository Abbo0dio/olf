import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../meds/meds_providers.dart';
import '../providers.dart';
import '../settings/settings_providers.dart';
import 'modes_providers.dart';

/// `app_settings` key holding the timestamp the user last dismissed the
/// birth-control recalibration note (p7.8), as an ISO-8601 string. Absent means
/// never dismissed. A change dated after this timestamp brings the note back.
/// **No schema change** — one row in the existing KV store, like
/// `pregnancy.start_reference`.
const String birthControlRecalibrationDismissedKey =
    'mode.birthControlSwitch.dismissedAt';

/// The stored dismissal timestamp, live. `null` until one is set (or the
/// database is still opening).
final birthControlRecalibrationDismissedAtProvider = StreamProvider<DateTime?>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<DateTime?>.value(null);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(birthControlRecalibrationDismissedKey)
      .map((v) => v == null ? null : DateTime.tryParse(v));
});

/// The birth-control recalibration read (p7.8), or `null` when the mode is off,
/// there is no hormonal-BC change to react to, or the change is in the future.
///
/// Gated on [LifeStageMode.birthControlSwitch] being enabled — nothing shows
/// for a user who has not turned the mode on (Phase 7 "no mode clutters the
/// default home/calendar" rule). Pure `core` derivation; `DateTime.now()` is
/// read at this edge, matching `postpartumCycleReturnProvider`.
final birthControlRecalibrationProvider = Provider<BirthControlRecalibration?>((
  ref,
) {
  final modeOn =
      ref
          .watch(lifeStageModeEnabledProvider(LifeStageMode.birthControlSwitch))
          .valueOrNull ??
      false;
  if (!modeOn) return null;

  final entries =
      ref.watch(birthControlHistoryProvider).valueOrNull ??
      const <BirthControlEntry>[];
  final cycles = ref.watch(cyclesProvider);
  final dismissedAt = ref
      .watch(birthControlRecalibrationDismissedAtProvider)
      .valueOrNull;

  return deriveBirthControlRecalibration(
    entries: entries,
    cycles: cycles,
    today: DateTime.now(),
    dismissedAt: dismissedAt,
  );
});

/// Dismiss the recalibration note for the current change. Stores "now"; a later
/// change re-activates the note on its own.
Future<void> dismissBirthControlRecalibration(WidgetRef ref) => ref
    .read(settingsRepositoryProvider)
    .set(
      birthControlRecalibrationDismissedKey,
      DateTime.now().toIso8601String(),
    );
