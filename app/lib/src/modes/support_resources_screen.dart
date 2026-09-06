import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

import 'support_resources_content.dart';

/// Gentle, non-clinical support resources shown from postpartum mode (p7.1).
/// Content differs for a loss vs. a birth. All text is bundled — there are no
/// external links that phone home; an address, if one were shown, would be
/// plain selectable text, not a tracked link.
class SupportResourcesScreen extends StatelessWidget {
  const SupportResourcesScreen({required this.kind, super.key});

  final PregnancyEndKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = supportResourcesFor(kind);

    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(content.intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          for (final section in content.sections) ...[
            Text(section.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(section.body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
          ],
          const Divider(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_hospital_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  content.findCareLine,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            SupportResources.notMedicalDeviceLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
