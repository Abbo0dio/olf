import 'package:meta/meta.dart';

import '../cycle/cycle.dart';
import '../date_math.dart';
import '../db/app_database.dart';
import '../db/tables.dart';

/// Which hormonal-birth-control methods disrupt the cycle enough that a
/// prediction built on pre-switch cycles should be held back for a while
/// (p7.8).
///
/// Deliberately coarse — this is not per-method pharmacology (see
/// `docs/plan/phases/phase-07.md` #### p7.8, "the note is generic"). The
/// systemic hormonal methods are treated as hormonal; `iud` is left out because
/// the enum does not say copper vs. hormonal, and `other` is an unknown, so
/// neither should raise a recalibration note on its own.
extension BirthControlMethodHormonal on BirthControlMethod {
  bool get isHormonal => switch (this) {
    BirthControlMethod.pill ||
    BirthControlMethod.patch ||
    BirthControlMethod.ring ||
    BirthControlMethod.injection ||
    BirthControlMethod.implant => true,
    BirthControlMethod.iud ||
    BirthControlMethod.condom ||
    BirthControlMethod.other => false,
  };
}

/// Whether the recorded change was onto or off hormonal birth control — drives
/// the explainer copy (starting vs. stopping), nothing in the maths.
enum BirthControlSwitchDirection { started, stopped }

/// A derived, presentation-only read (p7.8) that says the cycle is still
/// settling after a hormonal-birth-control change, so the p3 forecast should be
/// held back rather than shown with false confidence.
///
/// Built entirely from the existing p1.7 [BirthControlEntry] history, the
/// derived [Cycle] list and an optional user-dismissal timestamp — there is no
/// new table and the predictor is untouched. Honest `null` when there is no
/// hormonal-BC change to speak of, or the change is dated in the future.
@immutable
class BirthControlRecalibration {
  const BirthControlRecalibration({
    required this.direction,
    required this.switchDate,
    required this.daysSinceSwitch,
    required this.windowDays,
    required this.postSwitchCycleCount,
    required this.postSwitchCyclesNeeded,
    required this.dismissed,
  });

  /// Whether the user started or stopped hormonal birth control.
  final BirthControlSwitchDirection direction;

  /// Calendar date of the change (a hormonal entry's start, or its end).
  final DateTime switchDate;

  /// Whole days from [switchDate] to the injected "today", never negative.
  final int daysSinceSwitch;

  /// Length of the recalibration window in days.
  final int windowDays;

  /// Completed, non-gap cycles whose period starts strictly after [switchDate].
  final int postSwitchCycleCount;

  /// How many post-switch cycles end the window early.
  final int postSwitchCyclesNeeded;

  /// `true` when the user dismissed the note for this change.
  final bool dismissed;

  /// Days left in the window, never negative.
  int get daysRemaining {
    final left = windowDays - daysSinceSwitch;
    return left < 0 ? 0 : left;
  }

  /// `true` once the window has run out.
  bool get windowElapsed => daysSinceSwitch > windowDays;

  /// `true` once enough post-switch cycles have been logged.
  bool get enoughPostSwitchCycles =>
      postSwitchCycleCount >= postSwitchCyclesNeeded;

  /// Whether the recalibration note should be shown and the forecast withheld:
  /// still inside the window, not yet enough post-switch cycles, and not
  /// dismissed.
  bool get active => !windowElapsed && !enoughPostSwitchCycles && !dismissed;

  @override
  bool operator ==(Object other) =>
      other is BirthControlRecalibration &&
      other.direction == direction &&
      other.switchDate == switchDate &&
      other.daysSinceSwitch == daysSinceSwitch &&
      other.windowDays == windowDays &&
      other.postSwitchCycleCount == postSwitchCycleCount &&
      other.postSwitchCyclesNeeded == postSwitchCyclesNeeded &&
      other.dismissed == dismissed;

  @override
  int get hashCode => Object.hash(
    direction,
    switchDate,
    daysSinceSwitch,
    windowDays,
    postSwitchCycleCount,
    postSwitchCyclesNeeded,
    dismissed,
  );
}

/// Default recalibration window: a hormonal-BC change commonly takes a couple of
/// months for the cycle to settle, and the first cycles after it are often
/// irregular. Not per-method — see [BirthControlMethodHormonal].
const int defaultBirthControlRecalibrationWindowDays = 90;

/// Default number of logged post-switch cycles that ends the window early.
const int defaultBirthControlPostSwitchCyclesNeeded = 3;

/// Derive the birth-control recalibration read from the p1.7 [entries], the
/// derived [cycles] (newest first, as `deriveCycles` returns them) and an
/// optional [dismissedAt] timestamp, as of [today] (injected — never
/// `DateTime.now()`).
///
/// Returns `null` when there is no hormonal-BC change to react to, or the most
/// recent one is dated in the future.
///
/// The "change" is the most recent of:
///  * **started** — the current open entry (`endedOn == null`) is a hormonal
///    method: the change is its `startedOn`;
///  * **stopped** — the current open entry is non-hormonal or there is none,
///    but a hormonal entry has been ended: the change is the latest such
///    `endedOn`.
///
/// [dismissedAt] clears the note only for the change it was dismissed against:
/// a later change (its date strictly after [dismissedAt]) brings the note back.
BirthControlRecalibration? deriveBirthControlRecalibration({
  required Iterable<BirthControlEntry> entries,
  required Iterable<Cycle> cycles,
  required DateTime today,
  DateTime? dismissedAt,
  int windowDays = defaultBirthControlRecalibrationWindowDays,
  int postSwitchCyclesNeeded = defaultBirthControlPostSwitchCyclesNeeded,
}) {
  final all = entries.toList()
    ..sort((a, b) => a.startedOn.compareTo(b.startedOn));
  if (all.isEmpty) return null;

  BirthControlEntry? open;
  for (final e in all) {
    if (e.endedOn == null) open = e;
  }

  BirthControlSwitchDirection? direction;
  DateTime? switchDate;

  if (open != null && open.method.isHormonal) {
    direction = BirthControlSwitchDirection.started;
    switchDate = dateOnly(open.startedOn);
  } else {
    DateTime? latestHormonalEnd;
    for (final e in all) {
      if (!e.method.isHormonal || e.endedOn == null) continue;
      final end = dateOnly(e.endedOn!);
      if (latestHormonalEnd == null || end.isAfter(latestHormonalEnd)) {
        latestHormonalEnd = end;
      }
    }
    if (latestHormonalEnd != null) {
      direction = BirthControlSwitchDirection.stopped;
      switchDate = latestHormonalEnd;
    }
  }

  if (direction == null || switchDate == null) return null;

  final day = dateOnly(today);
  if (switchDate.isAfter(day)) return null;

  final daysSinceSwitch = daysBetween(switchDate, day);

  final postSwitchCycleCount = cycles
      .where((c) => c.periodStart.isAfter(switchDate!))
      .where((c) => !c.isCurrent && !c.isLikelyGap && !c.isPregnancyGap)
      .length;

  final dismissed =
      dismissedAt != null && !dateOnly(dismissedAt).isBefore(switchDate);

  return BirthControlRecalibration(
    direction: direction,
    switchDate: switchDate,
    daysSinceSwitch: daysSinceSwitch,
    windowDays: windowDays,
    postSwitchCycleCount: postSwitchCycleCount,
    postSwitchCyclesNeeded: postSwitchCyclesNeeded,
    dismissed: dismissed,
  );
}
