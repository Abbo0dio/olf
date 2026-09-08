import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../bbt/bbt_chart_widget.dart';
import '../bbt/bbt_providers.dart';
import '../cycle/cycle_format.dart';
import '../cycle/cycle_providers.dart';
import '../modes/correlation_chart.dart';
import '../modes/mode_catalog.dart';
import '../modes/modes_page.dart';
import '../modes/modes_providers.dart';
import '../modes/pcos_correlation_format.dart';
import '../modes/perimenopause_format.dart';
import '../period/period_format.dart';
import '../prediction/accuracy_format.dart';
import '../prediction/accuracy_page.dart';
import 'patterns_providers.dart';

/// The Patterns tab (r3b): the longer-term views, moved off the Home scroll and
/// out of Settings.
///
/// Sections, top to bottom:
/// * **Prediction accuracy** — a row into [AccuracyPage] (was Settings → Cycle).
/// * **Your cycles** — the cycle-length / variability card (relocated from the
///   Home tab, where r3a parked it).
/// * **Basal temperature** — a per-cycle sparkline for every cycle with two or
///   more basal readings (the Home "this cycle" card is this-cycle-only).
/// * **Symptoms across your cycle** — the p7.4 [CorrelationChart], one bar per
///   symptom that has enough placed days; the section is hidden until something
///   qualifies.
/// * **Modes** — an "Open" row for each enabled mode, then the entry to the
///   Modes on/off screen ([ModesPage], was Settings → Modes).
///
/// Every section reuses an existing empty / not-enough-data state — nothing here
/// fabricates a trend — and `reduceSpokenDetail` redaction is carried on the one
/// moved read-out that names a symptom (the correlations section).
class PatternsView extends ConsumerWidget {
  const PatternsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final stats = ref.watch(cycleStatsProvider);
    final pcosMode =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.pcos))
            .valueOrNull ??
        false;
    final perimenopauseMode =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.perimenopause))
            .valueOrNull ??
        false;

    final cycles = ref.watch(cyclesProvider);
    final bbtEntries =
        ref.watch(bbtEntriesProvider).valueOrNull ?? const <BbtEntry>[];
    final unit =
        ref.watch(temperatureUnitProvider).valueOrNull ??
        TemperatureUnit.celsius;
    final bbtCharts = <_CycleChart>[
      for (final cycle in cycles)
        if (bbtChartForCycle(cycle, bbtEntries) case final points
            when points.length >= 2)
          _CycleChart(
            label: cycle.isCurrent
                ? 'This cycle'
                : 'Cycle from ${formatDay(cycle.periodStart)}',
            points: points,
          ),
    ];

    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
    final correlations = [
      for (final c in ref.watch(symptomPhaseCorrelationsProvider))
        if (c.enoughData) c,
    ];

    final enabledModes = <LifeStageMode>[
      for (final mode in LifeStageMode.values)
        if (ref.watch(lifeStageModeEnabledProvider(mode)).valueOrNull ?? false)
          mode,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _NavRow(
          icon: Icons.insights_outlined,
          title: accuracySettingsTitle,
          subtitle: accuracySettingsSubtitle,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const AccuracyPage())),
        ),

        const _SectionHeader('Your cycles'),
        _CycleStatsCard(
          stats: stats,
          pcosMode: pcosMode,
          perimenopauseMode: perimenopauseMode,
        ),

        const _SectionHeader('Basal temperature'),
        if (bbtCharts.isEmpty)
          Text(
            'Log two or more basal temperatures within one cycle to see a '
            'chart here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final chart in bbtCharts) ...[
            Text(chart.label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            BbtChart(points: chart.points, unit: unit),
            const SizedBox(height: 16),
          ],

        if (correlations.isNotEmpty) ...[
          const _SectionHeader('Symptoms across your cycle'),
          Text(
            'How your logged symptoms have fallen across cycle phases. '
            'Descriptive only.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final c in correlations) ...[
            Text(
              c.category,
              style: theme.textTheme.titleSmall,
              semanticsLabel: spokenLabel(reduceSpoken, redacted: 'symptom'),
            ),
            const SizedBox(height: 8),
            CorrelationChart(
              label: reduceSpoken ? 'symptom' : c.category,
              daysByPhase: c.daysByPhase,
            ),
            const SizedBox(height: 16),
          ],
        ],

        const _SectionHeader('Modes'),
        for (final mode in enabledModes)
          _NavRow(
            title: 'Open ${modeCatalogEntry(mode).title}',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => modeScreen(mode))),
          ),
        _NavRow(
          icon: Icons.tune_outlined,
          title: 'Life-stage & condition modes',
          subtitle:
              'Optional lenses — postpartum, pregnancy, PCOS and more. All '
              'off until you turn them on.',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ModesPage())),
        ),
      ],
    );
  }
}

/// One [BbtChart] plus the cycle label it belongs to.
class _CycleChart {
  const _CycleChart({required this.label, required this.points});

  final String label;
  final List<BbtChartPoint> points;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A plain navigation row (icon + title + optional subtitle + chevron).
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Cycle-length and variability summary, shown once at least one period exists.
/// Falls back to a "keep logging" nudge rather than assuming any cycle length.
/// Relocated from the Home tab (r3b).
class _CycleStatsCard extends StatelessWidget {
  const _CycleStatsCard({
    required this.stats,
    this.pcosMode = false,
    this.perimenopauseMode = false,
  });

  final CycleStats stats;

  /// p7.4 / p7.7: soften the likely-gap / irregular wording (long, variable and
  /// skipped cycles are expected in PCOS and perimenopause modes). The [stats]
  /// themselves are unchanged.
  final bool pcosMode;
  final bool perimenopauseMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typical = stats.typicalCycleLength;
    final hasRange = stats.shortestCycleLength != stats.longestCycleLength;
    final regularityLabel =
        (pcosMode || perimenopauseMode) &&
            stats.regularity == CycleRegularity.irregular
        ? '${stats.regularity.label} — expected in this mode'
        : stats.regularity.label;

    return Semantics(
      container: true,
      label:
          'Cycle insights. '
          '${summariseStats(stats, pcosMode: pcosMode, perimenopauseMode: perimenopauseMode)}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (typical != null) ...[
              Text(
                '$typical-day typical cycle',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                hasRange
                    ? '${stats.shortestCycleLength}–${stats.longestCycleLength} '
                          'days  ·  $regularityLabel'
                    : regularityLabel,
                style: theme.textTheme.bodyMedium,
              ),
              if (stats.typicalPeriodLength != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Typical period ${stats.typicalPeriodLength} days',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (stats.hasLikelyGap) ...[
                const SizedBox(height: 6),
                Text(
                  pcosMode
                      ? pcosSoftenedGapLine
                      : perimenopauseMode
                      ? perimenopauseSoftenedGapLine
                      : 'A long gap is set aside — a period may not have been '
                            'logged then.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else
              Text(
                summariseStats(
                  stats,
                  pcosMode: pcosMode,
                  perimenopauseMode: perimenopauseMode,
                ),
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
