import 'package:flutter/material.dart';

import '../backup/backup_page.dart';
import 'privacy_education_content.dart';

/// Index of the three privacy explainers (p2.7). Reachable from the privacy
/// policy screen and from Settings → Privacy. Education only — the policy and
/// the consent switches live on `PrivacyPolicyScreen` (p2.5).
class PrivacyEducationScreen extends StatelessWidget {
  const PrivacyEducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(privacyEducationTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(privacyEducationIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final explainer in privacyExplainers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(explainer.title),
              subtitle: Text(explainer.summary),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PrivacyExplainerScreen(explainer: explainer),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One explainer's full text. The "delete everything" one also renders the
/// concrete numbered steps and a real hand-off button to Backup & restore.
class PrivacyExplainerScreen extends StatelessWidget {
  const PrivacyExplainerScreen({required this.explainer, super.key});

  final PrivacyExplainer explainer;

  bool get _isDelete => explainer.id == deleteEverythingExplainer.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(explainer.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          for (final paragraph in explainer.body) ...[
            Text(paragraph, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          if (_isDelete) ...[
            const SizedBox(height: 4),
            for (var i = 0; i < deleteEverythingSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deleteEverythingSteps[i],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackupPage()),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text(deleteEverythingBackupAction),
            ),
          ],
        ],
      ),
    );
  }
}
