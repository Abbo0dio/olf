import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'a11y/announce.dart';
import 'home_page.dart';
import 'onboarding/first_run_screen.dart';
import 'onboarding/onboarding_providers.dart';
import 'providers.dart';
import 'security/auto_lock_providers.dart';
import 'security/pin_providers.dart';
import 'security/pin_unlock_screen.dart';

/// User-facing copy for the inactivity auto-lock warning (p5.3). Gender-neutral,
/// no health detail — identical for the real and decoy sessions (p2.2).
const String autoLockWarningMessage =
    'Locking soon for privacy — tap to stay unlocked.';
const String autoLockWarningAnnouncement =
    'Locking soon for privacy. Tap to stay unlocked.';
const String autoLockStayAction = 'Stay unlocked';

/// The app's root gate (p1.8).
///
/// Order: database opens → first-run privacy explainer (once) → PIN lock (if
/// set and the session is locked) → [HomePage]. Backgrounding the app re-locks
/// it when a PIN is set; so does inactivity (p5.3) — after
/// [autoLockMinutesProvider] minutes with no interaction, with a ~20s warning
/// first. A database error falls through to [HomePage], which owns the
/// fail-safe screen.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  late final AppLifecycleListener _lifecycle;
  Timer? _inactivityTimer;
  bool _warningShowing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) {
          _relock();
        }
      },
    );
    // p5.3: measure the first inactivity deadline from mount. Done after the
    // first frame (not in initState) so it does not modify a provider mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bumpActivity();
    });
    // Poll the inactivity deadline. The maths is core's `nextAutoLockState`;
    // this only decides when to warn and when to lock.
    _inactivityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _evaluateAutoLock(),
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Re-lock the session (shared by the lifecycle path and inactivity expiry).
  /// Always resets the vault to real so the next unlock re-chooses it (p2.2) —
  /// nothing here differs between a real and a decoy session.
  void _relock() {
    if (!ref.read(pinIsSetProvider)) return;
    ref.read(sessionUnlockedProvider.notifier).state = false;
    ref.read(appVaultProvider.notifier).state = AppVault.real;
    _hideWarning();
  }

  /// Mark "the user just did something" — resets the inactivity deadline and
  /// clears any pending warning. Called on every pointer-down and from the
  /// warning's "Stay unlocked" action.
  void _bumpActivity() {
    if (!mounted) return;
    ref.read(lastInteractionProvider.notifier).state = ref.read(nowProvider)();
    if (_warningShowing) _hideWarning();
  }

  void _evaluateAutoLock() {
    if (!mounted) return;
    if (!ref.read(pinIsSetProvider)) return; // no lock → nothing to auto-lock
    if (!ref.read(sessionUnlockedProvider)) {
      if (_warningShowing) _hideWarning();
      return;
    }
    final minutes = ref.read(autoLockMinutesProvider).valueOrNull ?? 0;
    if (minutes <= 0) {
      if (_warningShowing) _hideWarning();
      return;
    }

    final decision = nextAutoLockState(
      lastActivity: ref.read(lastInteractionProvider),
      minutes: minutes,
      now: ref.read(nowProvider)(),
    );
    switch (decision.phase) {
      case AutoLockPhase.expired:
        _relock();
      case AutoLockPhase.warning:
        _showWarning();
      case AutoLockPhase.idle:
        if (_warningShowing) _hideWarning();
    }
  }

  void _showWarning() {
    if (_warningShowing || !mounted) return;
    _warningShowing = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    announce(context, autoLockWarningAnnouncement);
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text(autoLockWarningMessage),
            duration: const Duration(seconds: 30),
            action: SnackBarAction(
              label: autoLockStayAction,
              onPressed: _bumpActivity,
            ),
          ),
        )
        .closed
        .whenComplete(() {
          if (mounted) _warningShowing = false;
        });
  }

  void _hideWarning() {
    _warningShowing = false;
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    // Keep the inactivity window subscribed and resolved so the poll timer
    // reads a real value rather than `loading`.
    ref.watch(autoLockMinutesProvider);

    final child = switch (database) {
      AsyncError() => const HomePage(), // fail-safe screen lives there
      AsyncData() => _resolved(),
      _ => const _GateLoading(),
    };

    // p5.3: any pointer-down anywhere in the app resets the inactivity timer.
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _bumpActivity(),
      child: child,
    );
  }

  Widget _resolved() {
    final vault = ref.watch(appVaultProvider);
    final firstRunDone = ref.watch(firstRunDoneProvider);
    final credential = ref.watch(pinCredentialProvider);

    // If either preference read fails, degrade to the app rather than trap the
    // user behind a spinner.
    if (firstRunDone.hasError || credential.hasError) return const HomePage();
    if (!firstRunDone.hasValue || !credential.hasValue) {
      return const _GateLoading();
    }

    // The decoy vault (p2.2) is a "lived-in" app — never replay first-run there.
    if (vault == AppVault.real && firstRunDone.value != true) {
      return const FirstRunScreen();
    }

    final locked =
        credential.value != null && !ref.watch(sessionUnlockedProvider);
    return locked ? const PinUnlockScreen() : const HomePage();
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Starting olf',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
