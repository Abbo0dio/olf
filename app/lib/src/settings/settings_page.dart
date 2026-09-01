import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../backup/backup_page.dart';
import '../monetization/subscription_prompt_providers.dart';
import '../personalization/personalization_providers.dart';
import '../prediction/accuracy_format.dart';
import '../prediction/accuracy_page.dart';
import '../pregnancy/pregnancy_events_page.dart';
import '../privacy/privacy_education_content.dart';
import '../privacy/privacy_education_screen.dart';
import '../privacy/privacy_policy_content.dart';
import '../privacy/privacy_policy_screen.dart';
import '../providers.dart';
import '../reminders/notifications_page.dart';
import '../retention/retention_providers.dart';
import '../security/biometric_providers.dart';
import '../security/pin_providers.dart';
import '../theme/theme_providers.dart';

/// App settings (p1.8 lock; p1.9 appearance + pronouns; p1.10 backup;
/// p1.11 pregnancy loss & birth; p2.1 biometric unlock; p2.2 decoy PIN;
/// p2.3 auto-delete; p2.5 privacy policy; p2.7 privacy basics).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // p2.2: inside a decoy session the "App lock" rows manage the *decoy*
    // credential, and the "Decoy PIN" setup rows are hidden entirely, so nothing
    // hints that a decoy exists.
    final vault = ref.watch(appVaultProvider);
    final realPinSet = ref.watch(pinCredentialProvider).valueOrNull != null;
    final decoyPinSet =
        ref.watch(decoyPinCredentialProvider).valueOrNull != null;
    final pinSet = vault == AppVault.decoy ? decoyPinSet : realPinSet;
    final showDecoySetup = vault == AppVault.real && realPinSet;
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    final pronouns =
        ref.watch(pronounsProvider).valueOrNull ?? Pronouns.unspecified;
    final biometricCapable =
        ref.watch(biometricCapableProvider).valueOrNull ?? false;
    final biometricEnabled =
        ref.watch(biometricUnlockEnabledProvider).valueOrNull ?? false;
    final retentionWindow =
        ref.watch(retentionWindowProvider).valueOrNull ?? RetentionWindow.off;
    final subscriptionOffersHidden =
        !(ref.watch(subscriptionPromptsAllowedProvider).valueOrNull ?? true);

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
            onChanged: (want) => want
                ? _setPin(context, ref, vault)
                : _confirmRemove(context, ref, vault),
          ),
          if (pinSet)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change PIN'),
              onTap: () => _setPin(context, ref, vault),
            ),
          if (showDecoySetup)
            SwitchListTile(
              secondary: const Icon(Icons.shield_outlined),
              value: decoyPinSet,
              title: const Text('Decoy PIN'),
              subtitle: const Text(
                'A second PIN that opens a separate, empty olf. Use it if you '
                'are ever forced to unlock the app.',
              ),
              onChanged: (want) => want
                  ? _setDecoyPin(context, ref)
                  : _confirmRemoveDecoy(context, ref),
            ),
          if (showDecoySetup && decoyPinSet)
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Change decoy PIN'),
              onTap: () => _setDecoyPin(context, ref),
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
          ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: const Text('Auto-delete old entries'),
            subtitle: Text(
              retentionWindow == RetentionWindow.off
                  ? 'Keep everything until you remove it yourself.'
                  : 'Entries older than this are removed automatically and '
                        'left out of new backups.',
            ),
            trailing: Text(
              retentionWindow.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            onTap: () => _pickRetention(context, ref, retentionWindow),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(privacyPolicyTitle),
            subtitle: const Text(privacyPolicySettingsSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text(privacyEducationEntryLabel),
            subtitle: const Text(privacyEducationEntrySubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyEducationScreen(),
              ),
            ),
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
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text(accuracySettingsTitle),
            subtitle: const Text(accuracySettingsSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccuracyPage()),
            ),
          ),
          const _SectionHeader('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            subtitle: const Text(
              'Choose which reminders you get, each on its own schedule.',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
          const _SectionHeader('Subscriptions'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off_outlined),
            value: subscriptionOffersHidden,
            title: const Text("Don't show subscription offers"),
            subtitle: const Text(
              'Permanently hide any prompt about paid plans. Core tracking is '
              'free regardless. Turn this back on whenever you like.',
            ),
            // p4.5: on is immediate and final until the user turns it back off —
            // no confirmation, no "are you sure you'll miss out", no re-prompt.
            onChanged: (hide) =>
                setSubscriptionPromptsSuppressed(ref, suppressed: hide),
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

  Future<void> _setPin(
    BuildContext context,
    WidgetRef ref,
    AppVault vault,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(),
    );
    if (pin == null) return;
    final controller = ref.read(pinControllerProvider);
    if (vault == AppVault.decoy) {
      await controller.setDecoyPin(pin);
      messenger.showSnackBar(const SnackBar(content: Text('PIN updated.')));
    } else {
      await controller.setPin(pin);
      messenger.showSnackBar(const SnackBar(content: Text('App lock is on.')));
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppVault vault,
  ) async {
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
    final controller = ref.read(pinControllerProvider);
    if (vault == AppVault.decoy) {
      await controller.clearDecoyPin();
    } else {
      await controller.clearPin();
    }
    messenger.showSnackBar(const SnackBar(content: Text('App lock is off.')));
  }

  Future<void> _setDecoyPin(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _SetPinDialog(),
    );
    if (pin == null) return;
    final controller = ref.read(pinControllerProvider);
    if (await controller.matchesRealPin(pin)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Choose a code different from your main PIN.'),
        ),
      );
      return;
    }
    await controller.setDecoyPin(pin);
    messenger.showSnackBar(const SnackBar(content: Text('Decoy PIN is on.')));
  }

  Future<void> _confirmRemoveDecoy(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off the decoy PIN?'),
        content: const Text(
          'The separate decoy space stays on the device but can no longer be '
          'opened.',
        ),
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
    await ref.read(pinControllerProvider).clearDecoyPin();
    messenger.showSnackBar(const SnackBar(content: Text('Decoy PIN is off.')));
  }

  Future<void> _pickRetention(
    BuildContext context,
    WidgetRef ref,
    RetentionWindow current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosen = await showDialog<RetentionWindow>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Auto-delete old entries'),
        children: [
          RadioGroup<RetentionWindow>(
            groupValue: current,
            onChanged: (v) => Navigator.of(dialogContext).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final w in RetentionWindow.values)
                  RadioListTile<RetentionWindow>(
                    value: w,
                    title: Text(
                      w == RetentionWindow.off
                          ? 'Off — keep everything'
                          : w.label,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (chosen == null || chosen == current) return;
    if (chosen != RetentionWindow.off) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete older entries now?'),
          content: const Text(
            'Entries older than this will be permanently deleted now and kept '
            "out of future backups. This can't be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(retentionControllerProvider).setWindow(chosen);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          chosen == RetentionWindow.off
              ? 'Auto-delete turned off.'
              : 'Old entries will be cleaned up automatically.',
        ),
      ),
    );
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
