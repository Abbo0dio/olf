import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../security/pin_providers.dart';
import '../settings/settings_providers.dart';
import 'disclaimers.dart';
import 'onboarding_providers.dart';

/// Shown once, before anything else, on a fresh install (p1.8).
///
/// Plainly states: data is on this device, HIPAA does not apply, not medical
/// advice, not a contraceptive. Offers an optional numeric PIN. "Continue"
/// records acknowledgement (`onboarding_complete`) and enters the app.
class FirstRunScreen extends ConsumerStatefulWidget {
  const FirstRunScreen({super.key});

  @override
  ConsumerState<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends ConsumerState<FirstRunScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _wantPin = false;
  bool _busy = false;
  String? _pinError;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    var pin = '';
    if (_wantPin) {
      pin = _pinController.text;
      final formatError = validatePin(pin);
      if (formatError != null) {
        setState(() => _pinError = formatError.describe());
        return;
      }
      if (pin != _confirmController.text) {
        setState(() => _pinError = "Those PINs don't match.");
        return;
      }
    }

    setState(() {
      _busy = true;
      _pinError = null;
    });
    if (_wantPin) {
      await ref.read(pinControllerProvider).setPin(pin);
    }
    await ref
        .read(settingsRepositoryProvider)
        .set(SettingKeys.onboardingComplete, 'true');
    // Entering straight from setup counts as unlocked for this session.
    ref.read(sessionUnlockedProvider.notifier).state = true;
    ref.invalidate(firstRunDoneProvider);
    ref.invalidate(pinCredentialProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(disclaimerTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                for (final (heading, body) in disclaimerPoints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(heading, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                const Divider(height: 32),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _wantPin,
                  title: const Text(disclaimerPinOptInLabel),
                  subtitle: const Text(disclaimerPinOptInHint),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _wantPin = v ?? false;
                          _pinError = null;
                        }),
                ),
                if (_wantPin) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: maxPinLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                  ),
                  TextField(
                    controller: _confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: maxPinLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                      errorText: _pinError,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _continue,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(disclaimerAcknowledgeLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
