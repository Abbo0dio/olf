import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/app_gate.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_app/src/security/auto_lock_providers.dart';
import 'package:olf_app/src/security/pin_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// p5.3 — the inactivity auto-lock wired into `AppGate`. Deadline maths is
/// covered in `core/test/security/auto_lock_test.dart`; this checks the
/// widget-side behaviour: it re-locks after the window, a tap in the warning
/// window cancels it, and a decoy session re-locks identically.
void main() {
  final t0 = DateTime(2026, 9, 3, 10, 0, 0);

  PinCredential cred(String pin) =>
      derivePinCredential(pin, iterations: 400, random: Random(42));

  /// Overrides for an unlocked session behind a 1-minute auto-lock, with a
  /// test-controlled clock.
  List<Override> lockOverrides(DateTime Function() clock, {int minutes = 1}) =>
      [
        dbOverride(memoryDb()),
        nowProvider.overrideWithValue(clock),
        sessionUnlockedProvider.overrideWith((ref) => true),
        autoLockMinutesProvider.overrideWith((ref) => Stream.value(minutes)),
      ];

  testWidgets('re-locks the session after the inactivity window', (
    tester,
  ) async {
    var clock = t0;
    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      overrides: lockOverrides(() => clock),
      body: () async {
        expect(find.text('Enter your PIN'), findsNothing); // unlocked

        clock = t0.add(const Duration(seconds: 65)); // past the 1-min deadline
        await tester.pump(const Duration(seconds: 6)); // fire the poll
        await flush(tester);

        expect(find.text('Enter your PIN'), findsOneWidget); // re-locked
      },
    );
  });

  testWidgets('a tap in the warning window keeps the session unlocked', (
    tester,
  ) async {
    var clock = t0;
    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      overrides: lockOverrides(() => clock),
      body: () async {
        // 45s in → 15s left → inside the 20s warn lead.
        clock = t0.add(const Duration(seconds: 45));
        await tester.pump(const Duration(seconds: 6));
        await flush(tester);

        expect(find.text(autoLockWarningMessage), findsOneWidget);
        expect(find.text('Enter your PIN'), findsNothing);

        // "Stay unlocked" bumps the activity clock.
        await tester.tap(find.text(autoLockStayAction));
        await flush(tester);

        // 30s after that interaction — still well inside a fresh 60s window.
        clock = t0.add(const Duration(seconds: 75));
        await tester.pump(const Duration(seconds: 6));
        await flush(tester);

        expect(find.text('Enter your PIN'), findsNothing); // never locked
      },
    );
  });

  testWidgets('a decoy session re-locks the same way, with the same warning', (
    tester,
  ) async {
    var clock = t0;
    await pumpOlf(
      tester,
      pinStore: FakePinStore(cred('1379')),
      decoyPinStore: FakePinStore(cred('4680')),
      overrides: [
        ...lockOverrides(() => clock),
        appVaultProvider.overrideWith((ref) => AppVault.decoy),
      ],
      body: () async {
        expect(find.text('Enter your PIN'), findsNothing);

        clock = t0.add(const Duration(seconds: 45));
        await tester.pump(const Duration(seconds: 6));
        await flush(tester);
        // Identical warning copy — nothing signals which vault was open.
        expect(find.text(autoLockWarningMessage), findsOneWidget);

        clock = t0.add(const Duration(seconds: 65));
        await tester.pump(const Duration(seconds: 6));
        await flush(tester);

        expect(find.text('Enter your PIN'), findsOneWidget); // re-locked
      },
    );
  });
}
