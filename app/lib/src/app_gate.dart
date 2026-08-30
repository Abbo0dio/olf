import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_page.dart';
import 'onboarding/first_run_screen.dart';
import 'onboarding/onboarding_providers.dart';
import 'providers.dart';
import 'security/pin_providers.dart';
import 'security/pin_unlock_screen.dart';

/// The app's root gate (p1.8).
///
/// Order: database opens → first-run privacy explainer (once) → PIN lock (if
/// set and the session is locked) → [HomePage]. Backgrounding the app re-locks
/// it when a PIN is set. A database error falls through to [HomePage], which
/// owns the fail-safe screen.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) {
          if (ref.read(pinIsSetProvider)) {
            ref.read(sessionUnlockedProvider.notifier).state = false;
            // Never resume straight into a decoy session — the next unlock must
            // choose the vault again (p2.2).
            ref.read(appVaultProvider.notifier).state = AppVault.real;
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);

    return switch (database) {
      AsyncError() => const HomePage(), // fail-safe screen lives there
      AsyncData() => _resolved(),
      _ => const _GateLoading(),
    };
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
