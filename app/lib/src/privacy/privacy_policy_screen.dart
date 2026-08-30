import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'privacy_education_content.dart';
import 'privacy_education_screen.dart';
import 'privacy_policy_content.dart';
import 'privacy_providers.dart';

/// The standalone privacy policy (p2.5) — the whole policy in the app, not a
/// link out. Reachable from the first-run screen and from Settings → Privacy.
///
/// Holds the plain-language commitments plus the two consent switches
/// ("Your choices"), both off by default. The educational explainers (HIPAA
/// gap, law-enforcement reality, delete walkthrough) are p2.7 and are linked
/// from the bottom of this screen.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analyticsOptIn =
        ref.watch(analyticsOptInProvider).valueOrNull ?? false;
    final dataSharingOptIn =
        ref.watch(dataSharingOptInProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text(privacyPolicyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(privacyPolicyIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            privacyPolicyLastUpdated,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final (heading, body) in privacyPolicySections) ...[
            Text(heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
          const Divider(height: 32),
          Text(privacyChoicesHeading, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(privacyChoicesIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: analyticsOptIn,
            title: const Text(analyticsOptInLabel),
            subtitle: const Text(analyticsOptInHint),
            onChanged: (v) => setAnalyticsOptIn(ref, value: v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: dataSharingOptIn,
            title: const Text(dataSharingOptInLabel),
            subtitle: const Text(dataSharingOptInHint),
            onChanged: (v) => setDataSharingOptIn(ref, value: v),
          ),
          const SizedBox(height: 8),
          Text(
            privacyChoicesFootnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined),
            title: const Text(privacyEducationEntryLabel),
            subtitle: const Text(privacyEducationEntrySubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyEducationScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
