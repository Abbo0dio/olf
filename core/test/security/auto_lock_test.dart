import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p5.3 — inactivity auto-lock deadline maths. Pure, clock-injected.
void main() {
  final t0 = DateTime(2026, 9, 3, 10, 0, 0);

  AutoLockDecision at(
    Duration sinceActivity, {
    int? minutes = 2,
    Duration warnLead = kAutoLockWarnLead,
  }) => nextAutoLockState(
    lastActivity: t0,
    minutes: minutes,
    now: t0.add(sinceActivity),
    warnLead: warnLead,
  );

  group('auto-lock off', () {
    test('null minutes never warns or expires, no deadline', () {
      final d = at(const Duration(hours: 5), minutes: null);
      expect(d.phase, AutoLockPhase.idle);
      expect(d.deadline, isNull);
      expect(d.secondsUntilLock, -1);
    });

    test('zero (and negative) minutes is off', () {
      expect(
        at(const Duration(hours: 5), minutes: 0).phase,
        AutoLockPhase.idle,
      );
      expect(
        at(const Duration(hours: 5), minutes: -3).phase,
        AutoLockPhase.idle,
      );
      expect(at(const Duration(hours: 5), minutes: 0).deadline, isNull);
    });
  });

  group('active window', () {
    test('well before the warn lead is idle with a live countdown', () {
      final d = at(const Duration(seconds: 30)); // 2 min window, 90s left
      expect(d.phase, AutoLockPhase.idle);
      expect(d.deadline, t0.add(const Duration(minutes: 2)));
      expect(d.secondsUntilLock, 90);
    });

    test('just outside the warn lead is still idle', () {
      // 21s remaining, warnLead 20s.
      final d = at(const Duration(minutes: 2) - const Duration(seconds: 21));
      expect(d.phase, AutoLockPhase.idle);
      expect(d.secondsUntilLock, 21);
    });
  });

  group('warning window', () {
    test('exactly warnLead before the deadline is warning (inclusive)', () {
      final d = at(const Duration(minutes: 2) - kAutoLockWarnLead);
      expect(d.phase, AutoLockPhase.warning);
      expect(d.secondsUntilLock, kAutoLockWarnLead.inSeconds);
    });

    test('inside the lead is warning', () {
      final d = at(const Duration(minutes: 2) - const Duration(seconds: 5));
      expect(d.phase, AutoLockPhase.warning);
      expect(d.secondsUntilLock, 5);
    });

    test('a custom warn lead is honoured', () {
      final d = at(
        const Duration(seconds: 40),
        minutes: 1,
        warnLead: const Duration(seconds: 25),
      );
      expect(d.phase, AutoLockPhase.warning); // 20s left, lead 25s
    });
  });

  group('expiry', () {
    test('exactly at the deadline is expired', () {
      final d = at(const Duration(minutes: 2));
      expect(d.phase, AutoLockPhase.expired);
      expect(d.secondsUntilLock, 0);
      expect(d.deadline, t0.add(const Duration(minutes: 2)));
    });

    test('past the deadline is expired', () {
      final d = at(const Duration(minutes: 10));
      expect(d.phase, AutoLockPhase.expired);
      expect(d.secondsUntilLock, 0);
    });
  });

  group('activity reset', () {
    test('a fresh lastActivity pulls the state back to idle', () {
      final now = t0.add(
        const Duration(minutes: 5),
      ); // long past the old window
      final stale = nextAutoLockState(lastActivity: t0, minutes: 2, now: now);
      expect(stale.phase, AutoLockPhase.expired);

      final reset = nextAutoLockState(
        lastActivity: now, // interaction just happened
        minutes: 2,
        now: now,
      );
      expect(reset.phase, AutoLockPhase.idle);
      expect(reset.secondsUntilLock, 120);
      expect(reset.deadline, now.add(const Duration(minutes: 2)));
    });
  });
}
