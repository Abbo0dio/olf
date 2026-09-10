import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../widgets/empty_state.dart';
import 'correlation_chart.dart';
import 'endometriosis_format.dart';
import 'endometriosis_mode_providers.dart';
import 'endometriosis_pain_sheet.dart';

/// Endometriosis mode (p7.5): log pain (ordered intensity + optional region +
/// optional note) and flares, and see how they line up with cycle phase over
/// time. Descriptive only — no verdict, no diagnosis.
class EndometriosisScreen extends ConsumerWidget {
  const EndometriosisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(painEntriesProvider).valueOrNull ?? const [];
    final correlations = {
      for (final c in ref.watch(endometriosisCorrelationsProvider))
        c.category: c,
    };
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    final today = dateOnly(DateTime.now());
    final todayEntry = entries.where((e) => e.date == today).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Endometriosis')),
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
            child: Text(endoIntro, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EndometriosisPainSheet(),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(
              todayEntry == null ? "Log today's pain" : "Edit today's pain",
            ),
          ),
          if (todayEntry != null) ...[
            const SizedBox(height: 8),
            Text(
              'Today: ${painEntrySummary(todayEntry)}',
              style: theme.textTheme.bodyMedium,
              semanticsLabel: spokenLabel(
                reduceSpoken,
                redacted: painEntrySummaryRedacted,
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text(endoAcrossCycleHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            endoNotDiagnosisLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          if (entries.isEmpty)
            const EmptyState(
              message: endoEmptyState,
              icon: Icons.science_outlined,
            )
          else ...[
            _CategoryBlock(
              title: 'Flares',
              noun: 'flares',
              correlation: correlations[flareEventCategory],
              reduceSpoken: reduceSpoken,
            ),
            const SizedBox(height: 20),
            _CategoryBlock(
              title: 'Pain days',
              noun: 'pain days',
              correlation: correlations[painEventCategory],
              reduceSpoken: reduceSpoken,
            ),
          ],

          const SizedBox(height: 24),
          Text(
            endoDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.title,
    required this.noun,
    required this.correlation,
    required this.reduceSpoken,
  });

  final String title;
  final String noun;
  final PhaseCorrelation? correlation;
  final bool reduceSpoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = correlation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          c == null ? 'None logged yet.' : endoCorrelationLine(noun, c),
          style: theme.textTheme.bodyMedium,
          semanticsLabel: c == null
              ? null
              : spokenLabel(
                  reduceSpoken,
                  redacted: endoCorrelationLineRedacted(noun, c),
                ),
        ),
        if (c != null && c.enoughData) ...[
          const SizedBox(height: 10),
          CorrelationChart(label: title, daysByPhase: c.daysByPhase),
        ],
      ],
    );
  }
}
