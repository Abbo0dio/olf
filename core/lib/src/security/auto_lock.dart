import 'package:meta/meta.dart';

/// Inactivity auto-lock deadline maths (p5.3).
///
/// Pure, clock-injected — the caller passes `now`; nothing here reads the wall
/// clock. The app layer (`auto_lock_providers.dart` / `AppGate`) owns the
/// timer, the Settings option set, and the re-lock action; this file only says
/// *what state the lock is in* given how long since the last interaction.

/// The default lead time before the deadline during which the user is warned.
const Duration kAutoLockWarnLead = Duration(seconds: 20);

/// Where an inactivity-locked session stands right now.
enum AutoLockPhase {
  /// Auto-lock is off, or the deadline is still comfortably ahead.
  idle,

  /// Inside the warning lead: the session is still unlocked, but a countdown
  /// affordance should be shown and announced.
  warning,

  /// The deadline has passed — the session must re-lock now.
  expired,
}

/// The evaluated inactivity state.
@immutable
class AutoLockDecision {
  const AutoLockDecision({
    required this.phase,
    required this.deadline,
    required this.secondsUntilLock,
  });

  final AutoLockPhase phase;

  /// When the session locks, or `null` when auto-lock is off.
  final DateTime? deadline;

  /// Whole seconds from `now` until [deadline]: `-1` when auto-lock is off,
  /// `0` once expired, otherwise a positive countdown.
  final int secondsUntilLock;

  @override
  bool operator ==(Object other) =>
      other is AutoLockDecision &&
      other.phase == phase &&
      other.deadline == deadline &&
      other.secondsUntilLock == secondsUntilLock;

  @override
  int get hashCode => Object.hash(phase, deadline, secondsUntilLock);

  @override
  String toString() =>
      'AutoLockDecision($phase, deadline: $deadline, in ${secondsUntilLock}s)';
}

/// Evaluate the inactivity lock.
///
/// [minutes] `null` or `<= 0` means auto-lock is off → always [AutoLockPhase.idle]
/// with no deadline. Otherwise the deadline is [lastActivity] + [minutes]; the
/// result is [AutoLockPhase.expired] at or past it, [AutoLockPhase.warning]
/// within [warnLead] of it, and [AutoLockPhase.idle] before that.
///
/// A fresh [lastActivity] (bumped on every interaction) moves the deadline
/// forward and pulls the state back to `idle` — the caller resets it, this
/// function just re-reads it.
AutoLockDecision nextAutoLockState({
  required DateTime lastActivity,
  required int? minutes,
  required DateTime now,
  Duration warnLead = kAutoLockWarnLead,
}) {
  if (minutes == null || minutes <= 0) {
    return const AutoLockDecision(
      phase: AutoLockPhase.idle,
      deadline: null,
      secondsUntilLock: -1,
    );
  }

  final deadline = lastActivity.add(Duration(minutes: minutes));
  final remaining = deadline.difference(now);

  if (remaining <= Duration.zero) {
    return AutoLockDecision(
      phase: AutoLockPhase.expired,
      deadline: deadline,
      secondsUntilLock: 0,
    );
  }

  return AutoLockDecision(
    phase: remaining <= warnLead ? AutoLockPhase.warning : AutoLockPhase.idle,
    deadline: deadline,
    secondsUntilLock: remaining.inSeconds,
  );
}
