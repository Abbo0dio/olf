import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../widgets/empty_state.dart';
import 'correlation_chart.dart';
import 'pmdd_format.dart';
import 'pmdd_mode_providers.dart';
import 'pmdd_rating_sheet.dart';

/// PMDD mode (p7.6): a quick daily multi-item rating on the shared
/// [SymptomSeverity] scale, an overlay of the higher-rated days by cycle phase,
/// and one descriptive luteal-vs-rest-of-cycle sentence. Descriptive only — no
/// DRSP score, no threshold, no "you have PMDD" (§9(12)).
class PmddScreen extends ConsumerWidget {
  const PmddScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(pmddRatingsProvider).valueOrNull ?? const [];
    final today = ref.watch(pmddTodayRatingProvider);
    final overlay = ref.watch(pmddOverlayProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('PMDD')),
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
            child: Text(pmddIntro, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PmddRatingSheet()),
            ),
            icon: const Icon(Icons.add),
            label: Text(pmddRateButtonLabel(ratedToday: today.isNotEmpty)),
          ),
          if (today.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pmddDaySummary(today),
              style: theme.textTheme.bodyMedium,
              semanticsLabel: spokenLabel(
                reduceSpoken,
                redacted: pmddDaySummaryRedacted,
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text(pmddAcrossCycleHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            pmddNotDiagnosisLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          if (rows.isEmpty)
            const EmptyState(
              message: pmddEmptyState,
              icon: Icons.science_outlined,
            )
          else if (overlay != null) ...[
            Text(
              pmddLutealSummary(overlay.lutealRead),
              style: theme.textTheme.bodyMedium,
              semanticsLabel: spokenLabel(
                reduceSpoken,
                redacted: pmddLutealSummaryRedacted(overlay.lutealRead),
              ),
            ),
            if (overlay.enoughData) ...[
              const SizedBox(height: 14),
              CorrelationChart(
                label: 'Higher-rated days',
                daysByPhase: overlay.notableDaysByPhase,
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text(
            pmddDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
