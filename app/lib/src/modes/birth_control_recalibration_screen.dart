import 'package:flutter/material.dart';

import 'birth_control_recalibration_content.dart';

/// The short guided explainer for the birth-control-switching recalibration
/// state (p7.8): what to expect after starting vs. stopping hormonal birth
/// control, withdrawal bleeds vs. true cycles, and what olf does in the
/// meantime. All text is bundled — there are no external links that phone home.
/// Reached from Settings → Modes and from the "Learn more" action on the
/// prediction surface.
class BirthControlRecalibrationScreen extends StatelessWidget {
  const BirthControlRecalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const content = birthControlRecalibrationContent;

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
            BirthControlRecalibrationContent.notMedicalDeviceLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
