import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'biometric_gateway.dart';
import 'biometric_providers.dart';
import 'pin_providers.dart';

/// The lock screen shown when a PIN is set and the session is not unlocked
/// (p1.8). p2.1 adds an optional biometric shortcut: when the user has turned it
/// on and the device supports it, the biometric prompt fires automatically on
/// open and can be retried from a button. The PIN entry always stays available
/// as the fallback. Lockout / backoff and a decoy PIN are still Phase 2.
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _wrong = false;
  bool _biometricRunning = false;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrompt());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fire the biometric prompt once, on open, if the user opted in and the
  /// device can do it.
  Future<void> _maybeAutoPrompt() async {
    if (_autoPrompted) return;
    _autoPrompted = true;
    bool enabled;
    bool capable;
    try {
      enabled = await ref.read(biometricUnlockEnabledProvider.future);
      capable = await ref.read(biometricCapableProvider.future);
    } catch (_) {
      return; // no biometric available — just show the PIN
    }
    if (!mounted || !enabled || !capable) return;
    await _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_biometricRunning || _busy) return;
    setState(() => _biometricRunning = true);
    final result = await ref
        .read(biometricGatewayProvider)
        .authenticate(reason: 'Unlock olf');
    if (!mounted) return;
    if (result == BiometricAuthResult.success) {
      ref.read(sessionUnlockedProvider.notifier).state = true;
      return;
    }
    // failed / unavailable: quietly fall back to the PIN — no nagging.
    setState(() => _biometricRunning = false);
  }

  Future<void> _submit() async {
    if (_controller.text.length < minPinLength) return;
    setState(() {
      _busy = true;
      _wrong = false;
    });
    final ok = await ref.read(pinControllerProvider).verify(_controller.text);
    if (!mounted) return;
    if (ok) {
      ref.read(sessionUnlockedProvider.notifier).state = true;
    } else {
      setState(() {
        _busy = false;
        _wrong = true;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBiometrics =
        (ref.watch(biometricUnlockEnabledProvider).valueOrNull ?? false) &&
        (ref.watch(biometricCapableProvider).valueOrNull ?? false);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Enter your PIN', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: maxPinLength,
                    textAlign: TextAlign.center,
                    enabled: !_busy,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      errorText: _wrong ? 'Incorrect PIN. Try again.' : null,
                    ),
                    onChanged: (_) {
                      if (_wrong) setState(() => _wrong = false);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unlock'),
                  ),
                  if (showBiometrics) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _biometricRunning || _busy
                          ? null
                          : _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
