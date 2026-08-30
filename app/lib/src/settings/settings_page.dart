import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../backup/backup_page.dart';
import '../personalization/personalization_providers.dart';
import '../pregnancy/pregnancy_events_page.dart';
import '../security/biometric_providers.dart';
import '../security/pin_providers.dart';
import '../theme/theme_providers.dart';

/// App settings (p1.8 lock; p1.9 appearance + pronouns; p1.10 backup;
/// p1.11 pregnancy loss & birth; p2.1 biometric unlock).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinSet = ref.watch(pinCredentialProvider).valueOrNull != null;
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final pronouns =
        ref.watch(pronounsProvider).valueOrNull ?? Pronouns.unspecified;
    final biometricCapable =
        ref.watch(biometricCapableProvider).valueOrNull ?? false;
    final biometricEnabled =
        ref.watch(biometricUnlockEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: [
                for (final m in ThemeMode.values)
                  ButtonSegment(value: m, label: Text(themeModeLabel(m))),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setThemeMode(ref, s.first),
            ),
          ),
          const _SectionHeader('Pronouns'),
          RadioGroup<Pronouns>(
            groupValue: pronouns,
            onChanged: (v) => setPronouns(ref, v ?? Pronouns.unspecified),
            child: Column(
              children: [
                for (final p in Pronouns.values)
                  RadioListTile<Pronouns>(
                    value: p,
                    title: Text(describePronouns(p)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              pronounExampleSentence(pronouns),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const _SectionHeader('Privacy'),
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
          if (pinSet)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              value: biometricEnabled && biometricCapable,
              title: const Text('Unlock with biometrics'),
              subtitle: Text(
                biometricCapable
                    ? 'Use your fingerprint or face instead of typing the '
                          'PIN. The PIN still works as a fallback.'
                    : 'Add a fingerprint or face unlock in your device '
                          'settings to use this.',
              ),
              onChanged: biometricCapable
                  ? (want) => setBiometricUnlockEnabled(ref, enabled: want)
                  : null,
            ),
          const _SectionHeader('Cycle'),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Pregnancy loss & birth'),
            subtitle: const Text(
              'Record a loss or birth so estimates adjust around it.',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PregnancyEventsPage(),
              ),
            ),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.save_outlined),
            title: const Text('Backup & restore'),
            subtitle: const Text(
              'Save an encrypted copy of everything, or restore one.',
            ),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BackupPage())),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
