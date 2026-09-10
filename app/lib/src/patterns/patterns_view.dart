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
import '../widgets/empty_state.dart';
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

    // r5b: the Patterns list is **lazy** — each entry is a lightweight
    // [_PatternsItem], and the per-cycle BBT charts / correlation tiles (one
    // per logged period or placed symptom — unbounded) are built only when
    // scrolled into view. The itemBuilder closes solely over [data], which
    // holds pre-watched values; nothing in it touches [ref] (WidgetRef is only
    // legal inside a widget's own build).
    final data = _PatternsData(
      stats: stats,
      pcosMode: pcosMode,
      perimenopauseMode: perimenopauseMode,
      bbtCharts: bbtCharts,
      unit: unit,
      correlations: correlations,
      reduceSpoken: reduceSpoken,
      enabledModes: enabledModes,
      onOpenAccuracy: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AccuracyPage())),
      onOpenModes: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ModesPage())),
    );
    final items = <_PatternsItem>[
      _PatternsItem.accuracy(),
      _PatternsItem.header('Your cycles'),
      _PatternsItem.cycleStats(),
      _PatternsItem.header('Basal temperature'),
      if (bbtCharts.isEmpty)
        _PatternsItem.bbtEmpty()
      else
        for (final chart in bbtCharts) _PatternsItem.bbtChart(chart),
      if (correlations.isNotEmpty) ...[
        _PatternsItem.header('Symptoms across your cycle'),
        _PatternsItem.correlationLede(),
        for (final c in correlations) _PatternsItem.correlation(c),
      ],
      _PatternsItem.header('Modes'),
      for (final mode in enabledModes) _PatternsItem.modeRow(mode),
      _PatternsItem.modesEntry(),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i].build(context, data),
    );
  }
}

/// Pre-watched values the lazy item builders close over — never [ref] (see the
/// build above).
class _PatternsData {
  const _PatternsData({
    required this.stats,
    required this.pcosMode,
    required this.perimenopauseMode,
    required this.bbtCharts,
    required this.unit,
    required this.correlations,
    required this.reduceSpoken,
    required this.enabledModes,
    required this.onOpenAccuracy,
    required this.onOpenModes,
  });

  final CycleStats stats;
  final bool pcosMode;
  final bool perimenopauseMode;
  final List<_CycleChart> bbtCharts;
  final TemperatureUnit unit;
  final List<PhaseCorrelation> correlations;
  final bool reduceSpoken;
  final List<LifeStageMode> enabledModes;
  final VoidCallback onOpenAccuracy;
  final VoidCallback onOpenModes;
}

/// One row of the lazily-built Patterns list (r5b): a fixed entry, a section
/// header, or one per-cycle / per-symptom / per-mode payload row. Built only
/// when scrolled into view by [ListView.builder].
enum _PatternsItemKind {
  accuracy,
  header,
  cycleStats,
  bbtEmpty,
  bbtChart,
  correlationLede,
  correlation,
  modeRow,
  modesEntry,
}

class _PatternsItem {
  _PatternsItem.accuracy()
    : kind = _PatternsItemKind.accuracy,
      title = null,
      chart = null,
      correlation = null,
      mode = null;

  _PatternsItem.header(this.title)
    : kind = _PatternsItemKind.header,
      chart = null,
      correlation = null,
      mode = null;

  _PatternsItem.cycleStats()
    : kind = _PatternsItemKind.cycleStats,
      title = null,
      chart = null,
      correlation = null,
      mode = null;

  _PatternsItem.bbtEmpty()
    : kind = _PatternsItemKind.bbtEmpty,
      title = null,
      chart = null,
      correlation = null,
      mode = null;

  _PatternsItem.bbtChart(this.chart)
    : kind = _PatternsItemKind.bbtChart,
      title = null,
      correlation = null,
      mode = null;

  _PatternsItem.correlationLede()
    : kind = _PatternsItemKind.correlationLede,
      title = null,
      chart = null,
      correlation = null,
      mode = null;

  _PatternsItem.correlation(this.correlation)
    : kind = _PatternsItemKind.correlation,
      title = null,
      chart = null,
      mode = null;

  _PatternsItem.modeRow(this.mode)
    : kind = _PatternsItemKind.modeRow,
      title = null,
      chart = null,
      correlation = null;

  _PatternsItem.modesEntry()
    : kind = _PatternsItemKind.modesEntry,
      title = null,
      chart = null,
      correlation = null,
      mode = null;

  final _PatternsItemKind kind;
  final String? title;
  final _CycleChart? chart;
  final PhaseCorrelation? correlation;
  final LifeStageMode? mode;

  Widget build(BuildContext context, _PatternsData data) {
    final theme = Theme.of(context);
    return switch (kind) {
      _PatternsItemKind.accuracy => _NavRow(
        icon: Icons.insights_outlined,
        title: accuracySettingsTitle,
        subtitle: accuracySettingsSubtitle,
        onTap: data.onOpenAccuracy,
      ),
      _PatternsItemKind.header => _SectionHeader(title!),
      _PatternsItemKind.cycleStats => _CycleStatsCard(
        stats: data.stats,
        pcosMode: data.pcosMode,
        perimenopauseMode: data.perimenopauseMode,
      ),
      _PatternsItemKind.bbtEmpty => const EmptyState(
        message:
            'Log two or more basal temperatures within one cycle to see a '
            'chart here.',
        icon: Icons.thermostat_outlined,
      ),
      _PatternsItemKind.bbtChart => _ChartItem(chart: chart!, unit: data.unit),
      _PatternsItemKind.correlationLede => Text(
        'How your logged symptoms have fallen across cycle phases. '
        'Descriptive only.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      _PatternsItemKind.correlation => _CorrelationItem(
        c: correlation!,
        reduceSpoken: data.reduceSpoken,
      ),
      _PatternsItemKind.modeRow => _NavRow(
        title: 'Open ${modeCatalogEntry(mode!).title}',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => modeScreen(mode!))),
      ),
      _PatternsItemKind.modesEntry => _NavRow(
        icon: Icons.tune_outlined,
        title: 'Life-stage & condition modes',
        subtitle:
            'Optional lenses — postpartum, pregnancy, PCOS and more. All off '
            'until you turn them on.',
        onTap: data.onOpenModes,
      ),
    };
  }
}

/// One [BbtChart] plus the cycle label it belongs to — the label, the 4px gap
/// and the trailing 16px spacing ride along inside one list item.
class _ChartItem extends StatelessWidget {
  const _ChartItem({required this.chart, required this.unit});

  final _CycleChart chart;
  final TemperatureUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(chart.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        BbtChart(points: chart.points, unit: unit),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One symptom × cycle-phase correlation tile: the category title (redacted
/// under reduce-spoken-detail, exactly as before) + the shared bar chart.
class _CorrelationItem extends StatelessWidget {
  const _CorrelationItem({required this.c, required this.reduceSpoken});

  final PhaseCorrelation c;
  final bool reduceSpoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      // Neutral theme `Card` (was a hand-rolled radius-12 container) — one
      // accent per screen and it is not this one.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      ? '${stats.shortestCycleLength}–'
                            '${stats.longestCycleLength} days  ·  $regularityLabel'
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
                        : 'A long gap is set aside — a period may not have '
                              'been logged then.',
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
      ),
    );
  }
}
