import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import 'correlation_chart.dart';
import 'perimenopause_format.dart';
import 'perimenopause_mode_providers.dart';

/// Perimenopause / menopause mode (p7.7): a view built around rising cycle
/// variability and skipped cycles as the *expected* signal, a plain-language
/// "where things might be" read, and a timeline of perimenopause-relevant
/// symptoms against cycle phase. No score, no diagnosis — the §9(12) hard line.
class PerimenopauseScreen extends ConsumerWidget {
  const PerimenopauseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final read = ref.watch(perimenopauseTransitionProvider);
    final correlations = ref.watch(perimenopauseCorrelationsProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    final hint = read?.stageHint ?? PerimenopauseStageHint.notEnoughData;

    return Scaffold(
      appBar: AppBar(title: const Text('Perimenopause')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              perimenopauseExpectedSignalNote,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            perimenopauseTransitionHeading,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            perimenopauseTransitionLede,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            perimenopauseStageRead(hint),
            style: theme.textTheme.bodyMedium,
            semanticsLabel: spokenLabel(
              reduceSpoken,
              redacted: perimenopauseStageReadRedacted(hint),
            ),
          ),

          if (read != null && read.twelveMonthsSinceLastPeriod) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                perimenopauseTwelveMonthLine(read.daysSinceLastPeriod),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),
          Text(
            perimenopauseTimelineHeading,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            perimenopauseTimelineLede,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (correlations.isEmpty)
            Text(perimenopauseTimelineEmpty, style: theme.textTheme.bodyMedium)
          else
            for (final c in correlations) ...[
              _CorrelationTile(correlation: c, reduceSpoken: reduceSpoken),
              const SizedBox(height: 20),
            ],

          const SizedBox(height: 8),
          Text(
            perimenopauseDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrelationTile extends StatelessWidget {
  const _CorrelationTile({
    required this.correlation,
    required this.reduceSpoken,
  });

  final PhaseCorrelation correlation;
  final bool reduceSpoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(correlation.category, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          perimenopauseCorrelationLine(correlation),
          style: theme.textTheme.bodyMedium,
          semanticsLabel: spokenLabel(
            reduceSpoken,
            redacted: perimenopauseCorrelationLineRedacted(correlation),
          ),
        ),
        if (correlation.enoughData) ...[
          const SizedBox(height: 10),
          CorrelationChart(
            label: correlation.category,
            daysByPhase: correlation.daysByPhase,
          ),
        ],
      ],
    );
  }
}
