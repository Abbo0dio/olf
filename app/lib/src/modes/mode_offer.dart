import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'modes_providers.dart';
import 'postpartum_screen.dart';

/// After a pregnancy loss or birth is logged (p1.11), offer — calmly, and only
/// as an offer — to turn on postpartum mode (p7.1). The mode is **never**
/// auto-enabled: it turns on only if the user taps "Turn it on", and dismissing
/// the dialog does nothing.
Future<void> offerPostpartumMode(
  BuildContext context,
  WidgetRef ref,
  PregnancyEndKind kind,
) async {
  final noun = kind == PregnancyEndKind.loss ? 'loss' : 'birth';
  final turnedOn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Track your cycle coming back?'),
      content: Text(
        'olf can show a calm postpartum view: how long it has been since your '
        '$noun, when your first period returns, and whether your cycles are '
        'settling. It changes nothing about how you log — and you can turn it '
        'off any time without losing data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Turn it on'),
        ),
      ],
    ),
  );

  if (turnedOn != true) return;

  await setLifeStageModeEnabled(ref, LifeStageMode.postpartum, enabled: true);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Postpartum mode is on.'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PostpartumScreen()),
        ),
      ),
    ),
  );
}
