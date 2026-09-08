import 'package:flutter/material.dart';

/// The Patterns tab (r3a): an empty scaffold. r3b fills it with the longer-term
/// views (prediction accuracy, cycle stats, BBT history, symptom × cycle-phase
/// correlations, the enabled modes' rows, and the Modes on/off entry).
class PatternsView extends StatelessWidget {
  const PatternsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Your longer-term patterns will show here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
