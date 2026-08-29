import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../security/pin_providers.dart';

/// App settings (p1.8). For now just the optional app lock; p1.9 adds theme and
/// pronoun here.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = ref.watch(pinCredentialProvider).valueOrNull != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Privacy'),
          ),
          SwitchListTile(
            value: pinSet,
            title: const Text('App lock (PIN)'),
            subtitle: const Text(
              'Ask for a numeric code each time olf opens. This is a screen '
              'lock, not extra encryption.',
            ),
            onChanged: (want) =>
                want ? _setPin(context, ref) : _confirmRemove(context, ref),
          ),
          if (pinSet)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change PIN'),
              onTap: () => _setPin(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(),
    );
    if (pin == null) return;
    await ref.read(pinControllerProvider).setPin(pin);
    messenger.showSnackBar(const SnackBar(content: Text('App lock is on.')));
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off the app lock?'),
        content: const Text('olf will open without asking for a PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(pinControllerProvider).clearPin();
    messenger.showSnackBar(const SnackBar(content: Text('App lock is off.')));
  }
}

/// Two-field numeric PIN entry, validated as you type. Returns the PIN, or
/// `null` on cancel.
class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog();

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final formatError = validatePin(_pin.text);
    if (formatError != null) {
      setState(() => _error = formatError.describe());
      return;
    }
    if (_pin.text != _confirm.text) {
      setState(() => _error = "Those PINs don't match.");
      return;
    }
    Navigator.of(context).pop(_pin.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set a PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pin,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: maxPinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          TextField(
            controller: _confirm,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: maxPinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              counterText: '',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
