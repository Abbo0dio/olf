import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'backup_controller.dart';
import 'backup_providers.dart';

/// Export an encrypted backup file, or restore one (p1.10).
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(
        title: 'Set a passphrase',
        confirm: true,
        hint:
            'You will need this exact passphrase to restore the backup. It is '
            'not stored anywhere and cannot be recovered.',
      ),
    );
    if (passphrase == null) return;

    await _run(() async {
      final result = await ref
          .read(backupControllerProvider)
          .export(passphrase: passphrase);
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            ExportSaved() => 'Backup saved.',
            ExportCancelled() => 'Backup cancelled.',
          }),
        ),
      );
    });
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from a backup?'),
        content: const Text(
          'This replaces everything currently in olf with the contents of the '
          'backup file. There is no undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(
        title: 'Enter the backup passphrase',
        confirm: false,
        hint: 'The passphrase you chose when you created this backup.',
      ),
    );
    if (passphrase == null) return;

    await _run(() async {
      final result = await ref
          .read(backupControllerProvider)
          .restore(passphrase: passphrase);
      final message = switch (result) {
        RestoreDone(:final rowCount) => 'Restored $rowCount entries.',
        RestoreCancelled() => 'Restore cancelled.',
        RestoreWrongPassphrase() => 'That passphrase did not match the file.',
        RestoreBadFile(:final message) => message,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
      if (result is RestoreDone) {
        navigator.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'A backup is a single encrypted file that only your passphrase '
              'can open. It stays entirely on your device until you choose '
              'where to save it. Keep it somewhere safe — a lost passphrase '
              'cannot be recovered, and a backup is only as current as the day '
              'you made it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                'Create a backup',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Create an encrypted backup'),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                'Restore a backup',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Restoring replaces everything currently in olf.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restore from a backup file'),
            ),
            if (_busy) ...const [
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

/// One- or two-field passphrase entry, validated on submit. Returns the
/// passphrase, or `null` on cancel.
class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.title,
    required this.confirm,
    required this.hint,
  });

  final String title;
  final bool confirm;
  final String hint;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _passphrase.text;
    final formatError = validateBackupPassphrase(value);
    if (formatError != null) {
      setState(() => _error = formatError.describe());
      return;
    }
    if (widget.confirm && value != _confirm.text) {
      setState(() => _error = 'The two passphrases do not match.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.hint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _passphrase,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              errorText: widget.confirm ? null : _error,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: widget.confirm ? null : (_) => _submit(),
          ),
          if (widget.confirm)
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm passphrase',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
