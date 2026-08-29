import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'pin_providers.dart';

/// The lock screen shown when a PIN is set and the session is not unlocked
/// (p1.8). No lockout / backoff yet — that, plus biometric unlock and a decoy
/// PIN, is Phase 2.
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
