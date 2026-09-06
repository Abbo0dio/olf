import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import 'correlation_chart.dart';
import 'pcos_correlation_format.dart';
import 'pcos_mode_providers.dart';

/// PCOS mode (p7.4): an irregular-cycle-aware framing plus descriptive views of
/// how logged symptoms track cycle phase over time. No verdict, no diagnosis —
/// the not-a-symptom-checker line is stated plainly (contrast Flo's "ask your
/// doctor about PCOS", §9(12)).
class PcosScreen extends ConsumerWidget {
  const PcosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final correlations = ref.watch(pcosCorrelationsProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('PCOS')),
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
              pcosIrregularCycleNote,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          Text('Symptoms and your cycle', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            pcosNotSymptomCheckerLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (correlations.isEmpty)
            Text(
              'Log symptoms over a few cycles and this will show how they '
              'line up with cycle phase.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final c in correlations) ...[
              _CorrelationTile(correlation: c, reduceSpoken: reduceSpoken),
              const SizedBox(height: 20),
            ],
          const SizedBox(height: 8),
          Text(
            pcosDisclaimer,
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
          pcosCorrelationLine(correlation),
          style: theme.textTheme.bodyMedium,
          semanticsLabel: spokenLabel(
            reduceSpoken,
            redacted: pcosCorrelationLineRedacted(correlation),
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
