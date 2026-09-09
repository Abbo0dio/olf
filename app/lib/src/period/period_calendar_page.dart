import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/announce.dart';
import '../a11y/spoken_detail.dart';
import '../app_shell.dart';
import '../cycle/cycle_format.dart';
import '../cycle/cycle_providers.dart';
import '../cycle/cycle_wheel.dart';
import '../flow/flow_format.dart';
import '../flow/flow_providers.dart';
import '../bbt/bbt_chart_widget.dart';
import '../bbt/bbt_providers.dart';
import '../day_log/day_log_sheet.dart';
import '../modes/birth_control_recalibration_providers.dart';
import '../modes/mode_catalog.dart';
import '../modes/modes_page.dart';
import '../modes/modes_providers.dart';
import '../modes/perimenopause_mode_providers.dart';
import '../modes/postpartum_screen.dart';
import '../mucus/mucus_providers.dart';
import '../pregnancy/pregnancy_format.dart';
import '../pregnancy/pregnancy_providers.dart';
import '../prediction/correction_notice_providers.dart';
import '../prediction/forecast_area.dart';
import '../prediction/prediction_format.dart';
import '../prediction/prediction_providers.dart';
import '../symptom/symptom_format.dart';
import '../symptom/symptom_providers.dart';
import '../wearable/passive_phase_providers.dart';
import 'period_editor.dart';
import 'period_format.dart';
import 'period_providers.dart';

/// Which shell tab this instance renders (r3a).
enum HomeVariant {
  /// The slim home: cycle wheel, mode strip, forecast, "this cycle" card,
  /// recent activity. No month grid, no history list.
  home,

  /// The Calendar tab: the month grid + the full, lazily-built, year-grouped
  /// history.
  calendar,
}

/// The Home / Calendar tab body. Both variants share the same period-editing
/// plumbing (add / edit / delete / mark-start, the correction notice) and the
/// same "Log" FAB → [showDayLog]; they differ only in what they lay out.
///
/// Tapping any day — a calendar cell, the cycle wheel, the FAB, a recent-
/// activity row — opens the one unified day-log sheet (r2). For **today** the
/// sheet carries a one-tap "Mark today as period start" that writes the period
/// directly (r3a §5); a past day's "Start a period" still goes through the
/// period editor (p1.1).
class PeriodCalendarView extends ConsumerWidget {
  const PeriodCalendarView({super.key, this.variant = HomeVariant.home});

  final HomeVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(periodsProvider);
    return switch (periods) {
      AsyncData(:final value) => _Loaded(periods: value, variant: variant),
      AsyncError() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Could not read your periods.'),
        ),
      ),
      _ => Center(
        child: Semantics(
          label: 'Loading your periods',
          child: const CircularProgressIndicator(),
        ),
      ),
    };
  }
}

class _Loaded extends ConsumerStatefulWidget {
  const _Loaded({required this.periods, required this.variant});

  final List<Period> periods;
  final HomeVariant variant;

  @override
  ConsumerState<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends ConsumerState<_Loaded> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = firstOfMonth(DateTime.now());
  }

  List<Period> get _periods => widget.periods;

  Period? _periodOn(DateTime day) {
    for (final p in _periods) {
      if (isWithinRange(day, p.startDate, p.endDate)) return p;
    }
    return null;
  }

  Future<void> _openForDay(DateTime day) => _openDayLog(day);

  /// The one entry into the unified day-log sheet (r2). [lead] forces which
  /// section opens expanded; otherwise the sheet derives it from the day.
  Future<void> _openDayLog(DateTime day, {DayLogLead? lead}) {
    final period = _periodOn(day);
    final isToday = dateOnly(day) == dateOnly(DateTime.now());
    return showDayLog(
      context,
      date: day,
      lead: lead,
      onEditPeriodDates: period != null ? () => _edit(period) : null,
      onStartPeriod: (period == null && !isToday)
          ? () => _startPeriodOn(day)
          : null,
      onMarkPeriodStart: (period == null && isToday)
          ? _markTodayAsPeriodStart
          : null,
    );
  }

  // Adding a period is *logging* (`cyclesAdded`); editing or removing an
  // existing entry is *correcting* (`followedCorrection`). The distinction only
  // changes the wording of the note — `PredictionDelta` picks the right lead.
  static const _logging = PredictionChangeContext(cyclesAdded: 1);
  static const _correcting = PredictionChangeContext(followedCorrection: true);

  Future<void> _startPeriodOn(DateTime day) => _runHistoryEdit(
    () => showPeriodEditor(context, initialStart: day),
    _logging,
  );

  Future<void> _addPeriod() => _runHistoryEdit(
    () => showPeriodEditor(context, initialStart: DateTime.now()),
    _logging,
  );

  /// r3a §5: the one-tap "Mark today as period start" write. Builds **exactly**
  /// the draft the period editor's default today-Save builds
  /// (`addPeriod(PeriodDraft(start: today, end: null))`, nothing else) and runs
  /// it through the same outcome / correction-notice path — no editor surface.
  /// A validation failure (today already covered) is caught and surfaced, same
  /// as the editor's inline error; nothing is written.
  Future<void> _markTodayAsPeriodStart() => _runHistoryEdit(() async {
    final repo = ref.read(periodRepositoryProvider);
    try {
      await repo.addPeriod(PeriodDraft(start: dateOnly(DateTime.now())));
      return PeriodEditorOutcome.saved;
    } on PeriodValidationException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't mark today as a period.")),
        );
      }
      return null;
    }
  }, _logging);

  Future<void> _edit(Period period) => _runHistoryEdit(
    () => showPeriodEditor(context, existing: period),
    _correcting,
  );

  /// Run a period add / edit, then — if it actually changed something — show
  /// the "what changed" note. The before-prediction is captured *before* the
  /// edit; the after-prediction is recomputed from the freshly written data so
  /// the [PredictionDelta] is real and does not race the provider stream.
  Future<void> _runHistoryEdit(
    Future<PeriodEditorOutcome?> Function() edit,
    PredictionChangeContext change,
  ) async {
    final before = ref.read(predictionProvider);
    final outcome = await edit();
    if (!mounted) return;
    _reportOutcome(outcome);
    if (outcome == null) return;
    await _showCorrectionNotice(before, change);
  }

  Future<void> _showCorrectionNotice(
    CyclePrediction? before,
    PredictionChangeContext change,
  ) async {
    final periods = await ref.read(periodRepositoryProvider).allPeriods();
    final events = await ref
        .read(cycleEventRepositoryProvider)
        .pregnancyEvents();
    if (!mounted) return;
    final after = ref
        .read(predictorProvider)
        .predict(
          cycles: deriveCycles(periods, pregnancyEvents: events),
          today: DateTime.now(),
        );
    ref
        .read(correctionNoticeProvider.notifier)
        .show(
          PredictionDelta.between(
            before: before,
            after: after,
            context: change,
          ),
        );
  }

  Future<void> _deleteFromHistory(Period period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this period?'),
        content: Text(
          '${formatRange(period.startDate, period.endDate)} will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(periodRepositoryProvider);
    final restore = PeriodDraft(start: period.startDate, end: period.endDate);
    final before = ref.read(predictionProvider);
    await repo.deletePeriod(period.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Period deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repo.addPeriod(restore);
            ref.read(correctionNoticeProvider.notifier).clear();
          },
        ),
      ),
    );
    if (!mounted) return;
    await _showCorrectionNotice(before, _correcting);
  }

  void _reportOutcome(PeriodEditorOutcome? outcome) {
    if (outcome == null || !mounted) return;
    final text = switch (outcome) {
      PeriodEditorOutcome.saved => 'Period saved.',
      PeriodEditorOutcome.deleted => 'Period deleted.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _goToPatterns() => ref.read(appTabIndexProvider.notifier).state = 2;

  void _goToCalendar() => ref.read(appTabIndexProvider.notifier).state = 1;

  void _stepMonth(int delta) =>
      setState(() => _visibleMonth = addMonths(_visibleMonth, delta));

  void _jumpToToday() =>
      setState(() => _visibleMonth = firstOfMonth(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      // null tag: both variants mount at once in the shell's IndexedStack, so
      // a shared default hero tag would collide.
      heroTag: null,
      onPressed: () => _openDayLog(DateTime.now()),
      icon: const Icon(Icons.add),
      label: const Text('Log'),
    );
    return Scaffold(
      body: widget.variant == HomeVariant.home
          ? _HomeBody(state: this)
          : _CalendarBody(state: this),
      floatingActionButton: fab,
    );
  }
}

/// The slim Home tab.
class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  final _LoadedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();

    final flows = ref.watch(dailyFlowsProvider).value ?? const <DailyFlow>[];
    final symptomEntries =
        ref.watch(symptomEntriesProvider).value ?? const <DailySymptomEntry>[];
    final symptomTypes =
        ref.watch(symptomTypesProvider).value ?? const <SymptomType>[];
    final bbtEntries =
        ref.watch(bbtEntriesProvider).value ?? const <BbtEntry>[];
    final mucusEntries =
        ref.watch(cervicalMucusEntriesProvider).value ??
        const <CervicalMucusEntry>[];
    final tempUnit =
        ref.watch(temperatureUnitProvider).value ?? TemperatureUnit.celsius;

    final cycles = ref.watch(cyclesProvider);
    final prediction = ref.watch(predictionProvider);
    final correctionDelta = ref.watch(correctionNoticeProvider);
    final observedFertile = ref.watch(observedFertileWindowProvider);
    final currentCycle = cycles.isEmpty ? null : cycles.first;
    final cyclePhase = currentCyclePhase(
      cycle: currentCycle,
      prediction: prediction,
      today: today,
    );
    final bbtPoints = currentCycle == null
        ? const <BbtChartPoint>[]
        : bbtChartForCycle(currentCycle, bbtEntries);

    final pregnancyModeOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.pregnancy))
            .valueOrNull ??
        false;
    final pcosModeOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.pcos))
            .valueOrNull ??
        false;
    final perimenopauseModeOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.perimenopause))
            .valueOrNull ??
        false;
    final perimenopauseRead = perimenopauseModeOn
        ? ref.watch(perimenopauseTransitionProvider)
        : null;
    final perimenopauseGapSuppress =
        perimenopauseRead?.longGapsBetweenCycles ?? false;
    final pregnancyState = ref.watch(pregnancyRecoveryStateProvider);
    final pregnancySince = ref.watch(mostRecentPregnancyEndProvider)?.date;

    final bcRecalibration = ref.watch(birthControlRecalibrationProvider);
    final bcRecalActive = bcRecalibration?.active ?? false;

    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
    final passivePhase = ref.watch(passivePhaseEstimateProvider);

    final recent = _recentActivityDays(
      flows: flows,
      symptomEntries: symptomEntries,
      bbtEntries: bbtEntries,
      mucusEntries: mucusEntries,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CycleWheel(
            phase: cyclePhase,
            reduceSpoken: reduceSpoken,
            onTap: () => state._openDayLog(today),
          ),
          if (cyclePhase != null && passivePhase != null) ...[
            const SizedBox(height: 8),
            Text(
              passivePhaseNote(passivePhase),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              semanticsLabel: spokenDetail(
                reduceSpoken,
                full: passivePhaseNote(passivePhase),
                redacted: passivePhaseNoteRedacted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _PeriodStatusLine(periods: state._periods, today: today),
          const SizedBox(height: 12),
          const _ModeChipStrip(),
          if (pregnancyState != PregnancyRecoveryState.none) ...[
            const SizedBox(height: 16),
            _PregnancyStatusCard(state: pregnancyState, since: pregnancySince),
          ],
          if (correctionDelta != null) ...[
            const SizedBox(height: 16),
            _CorrectionNotice(
              delta: correctionDelta,
              reduceSpoken: reduceSpoken,
              onDismiss: () =>
                  ref.read(correctionNoticeProvider.notifier).clear(),
            ),
          ],
          ForecastArea(
            prediction: prediction,
            bcRecalActive: bcRecalActive,
            perimenopauseGapSuppress: perimenopauseGapSuppress,
            pregnancyModeOn: pregnancyModeOn,
            reduceSpoken: reduceSpoken,
            observedFertileWindow: observedFertile,
            pcosMode: pcosModeOn,
            perimenopauseMode: perimenopauseModeOn,
            onLogPeriodStart: state._addPeriod,
            onDismissRecalibration: () => dismissBirthControlRecalibration(ref),
          ),
          if (bbtPoints.length >= 2 ||
              prediction != null ||
              observedFertile != null) ...[
            const SizedBox(height: 16),
            _ThisCycleCard(
              points: bbtPoints,
              unit: tempUnit,
              fertileWindow: prediction?.fertileWindow,
              observedFertile: observedFertile,
              onTap: state._goToPatterns,
            ),
          ],
          const SizedBox(height: 24),
          _RecentActivity(
            days: recent,
            flows: {for (final f in flows) dateOnly(f.date): f},
            symptomIdsByDay: _symptomIdsByDay(symptomEntries),
            types: symptomTypes,
            reduceSpoken: reduceSpoken,
            onOpenDay: state._openForDay,
            onSeeAll: state._goToCalendar,
          ),
        ],
      ),
    );
  }
}

/// The Calendar tab: the month grid, then a lazy, year-grouped history list.
class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({required this.state});

  final _LoadedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final periods = state._periods;

    final flows = ref.watch(dailyFlowsProvider).value ?? const <DailyFlow>[];
    final flowByDay = {for (final f in flows) dateOnly(f.date): f};
    final symptomIdsByDay = _symptomIdsByDay(
      ref.watch(symptomEntriesProvider).value ?? const <DailySymptomEntry>[],
    );
    final cycles = ref.watch(cyclesProvider);
    final cycleByStart = {for (final c in cycles) c.periodStart: c};
    final pcosModeOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.pcos))
            .valueOrNull ??
        false;
    final perimenopauseModeOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.perimenopause))
            .valueOrNull ??
        false;
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    // Flatten to a lazy list of year headers + period rows.
    final items = <_CalItem>[];
    int? lastYear;
    for (final p in periods) {
      final y = p.startDate.year;
      if (y != lastYear) {
        items.add(_CalItem.year(y));
        lastYear = y;
      }
      items.add(_CalItem.period(p));
    }

    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _MonthCalendar(
              month: state._visibleMonth,
              today: today,
              periodOn: state._periodOn,
              flowOn: (d) => flowByDay[dateOnly(d)],
              symptomCountOn: (d) => symptomIdsByDay[dateOnly(d)]?.length ?? 0,
              reduceSpoken: reduceSpoken,
              onPrev: () => state._stepMonth(-1),
              onNext: state._visibleMonth.isBefore(firstOfMonth(today))
                  ? () => state._stepMonth(1)
                  : null,
              onJumpToToday: state._jumpToToday,
              onDayTap: state._openForDay,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text('History', style: theme.textTheme.titleMedium),
          ),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Nothing logged yet. Tap a day or the Log button.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                if (item.year != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      '${item.year}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final period = item.period!;
                return _HistoryRow(
                  period: period,
                  today: today,
                  cycle: cycleByStart[dateOnly(period.startDate)],
                  pcosMode: pcosModeOn,
                  perimenopauseMode: perimenopauseModeOn,
                  onOpen: () => state._openForDay(period.startDate),
                  onDelete: () => state._deleteFromHistory(period),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CalItem {
  _CalItem.year(this.year) : period = null;
  _CalItem.period(this.period) : year = null;
  final int? year;
  final Period? period;
}

Map<DateTime, List<int>> _symptomIdsByDay(List<DailySymptomEntry> entries) {
  final m = <DateTime, List<int>>{};
  for (final e in entries) {
    (m[dateOnly(e.date)] ??= <int>[]).add(e.symptomTypeId);
  }
  return m;
}

/// The most recent days (≤ 3) with anything logged — flow, symptom, temp or
/// cervical fluid — newest first.
List<DateTime> _recentActivityDays({
  required List<DailyFlow> flows,
  required List<DailySymptomEntry> symptomEntries,
  required List<BbtEntry> bbtEntries,
  required List<CervicalMucusEntry> mucusEntries,
}) {
  final days = <DateTime>{
    for (final f in flows) dateOnly(f.date),
    for (final s in symptomEntries) dateOnly(s.date),
    for (final b in bbtEntries) dateOnly(b.date),
    for (final m in mucusEntries) dateOnly(m.date),
  }.toList()..sort((a, b) => b.compareTo(a));
  return days.take(3).toList();
}

/// A one-line "where you are" status under the wheel: the running day count of
/// an ongoing period, otherwise the last logged period's range, otherwise a
/// nudge. (The old home summary's log chips are now the "Log" FAB's job.)
class _PeriodStatusLine extends StatelessWidget {
  const _PeriodStatusLine({required this.periods, required this.today});

  final List<Period> periods;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (periods.isEmpty) {
      return Text('No periods logged yet.', style: theme.textTheme.bodyLarge);
    }
    final latest = periods.first;
    final ongoing =
        latest.endDate == null &&
        !dateOnly(latest.startDate).isAfter(dateOnly(today));
    if (ongoing) {
      final day = dayCountSince(latest.startDate, today);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day $day',
            style: theme.textTheme.displaySmall,
            semanticsLabel: 'Day $day of your period',
          ),
          const SizedBox(height: 4),
          Text('Period started ${formatDay(latest.startDate)}'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last period', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          formatRange(latest.startDate, latest.endDate),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// A horizontal strip of chips, one per enabled life-stage/condition mode, each
/// opening that mode's screen. Renders nothing when no mode is on.
class _ModeChipStrip extends ConsumerWidget {
  const _ModeChipStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = <LifeStageMode>[
      for (final mode in LifeStageMode.values)
        if (ref.watch(lifeStageModeEnabledProvider(mode)).valueOrNull ?? false)
          mode,
    ];
    if (enabled.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final mode in enabled) ...[
            ActionChip(
              label: Text(modeCatalogEntry(mode).title),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => modeScreen(mode))),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// One glanceable card for the cycle in progress: the BBT sparkline, the
/// fertile-window estimate, and any observed fertile signs. The whole card taps
/// through to the Patterns tab.
class _ThisCycleCard extends StatelessWidget {
  const _ThisCycleCard({
    required this.points,
    required this.unit,
    required this.fertileWindow,
    required this.observedFertile,
    required this.onTap,
  });

  final List<BbtChartPoint> points;
  final TemperatureUnit unit;
  final DateRange? fertileWindow;
  final DateRange? observedFertile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      container: true,
      label: 'This cycle. Opens Patterns.',
      // Neutral theme `Card` (was a hand-rolled radius-12 container); the
      // ink splash is clipped to the card's rounded corners.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This cycle',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (points.length >= 2) ...[
                  const SizedBox(height: 8),
                  BbtChart(points: points, unit: unit),
                ],
                if (fertileWindow != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Estimated fertile window: '
                    '${formatDateRange(fertileWindow!)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (observedFertile != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Observed fertile signs: '
                    '${formatDateRange(observedFertile!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Recent activity" — the last ≤ 3 logged days, each opening the day-log sheet,
/// with a link across to the Calendar tab for the rest.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.days,
    required this.flows,
    required this.symptomIdsByDay,
    required this.types,
    required this.reduceSpoken,
    required this.onOpenDay,
    required this.onSeeAll,
  });

  final List<DateTime> days;
  final Map<DateTime, DailyFlow> flows;
  final Map<DateTime, List<int>> symptomIdsByDay;
  final List<SymptomType> types;
  final bool reduceSpoken;
  final ValueChanged<DateTime> onOpenDay;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (days.isEmpty)
          Text('Nothing logged yet.', style: theme.textTheme.bodyMedium)
        else
          for (final day in days)
            _RecentActivityRow(
              day: day,
              flow: flows[dateOnly(day)],
              symptomCount: symptomIdsByDay[dateOnly(day)]?.length ?? 0,
              reduceSpoken: reduceSpoken,
              onTap: () => onOpenDay(day),
            ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('See all in Calendar'),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({
    required this.day,
    required this.flow,
    required this.symptomCount,
    required this.reduceSpoken,
    required this.onTap,
  });

  final DateTime day;
  final DailyFlow? flow;
  final int symptomCount;
  final bool reduceSpoken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = flow;
    final parts = <String>[
      if (f != null) flowSemantics(f.intensity, f.clotSize),
      if (symptomCount > 0) symptomCountLabel(symptomCount),
    ];
    final detail = parts.isEmpty ? 'entry logged' : parts.join(', ');
    final semantic = reduceSpoken
        ? '${formatDay(day)}, has entries'
        : '${formatDay(day)}, $detail';
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(formatDay(day)),
        subtitle: parts.isEmpty
            ? null
            : Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.periodOn,
    required this.flowOn,
    required this.symptomCountOn,
    required this.reduceSpoken,
    required this.onPrev,
    required this.onNext,
    required this.onJumpToToday,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final Period? Function(DateTime) periodOn;
  final DailyFlow? Function(DateTime) flowOn;
  final int Function(DateTime) symptomCountOn;
  final bool reduceSpoken;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onJumpToToday;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = firstOfMonth(month);
    final leadingBlanks = first.weekday - DateTime.monday; // Mon-first grid
    final dayCount = daysInMonth(month);
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= dayCount; day++)
        _DayCell(
          date: DateTime(month.year, month.month, day),
          today: today,
          period: periodOn(DateTime(month.year, month.month, day)),
          flow: flowOn(DateTime(month.year, month.month, day)),
          symptomCount: symptomCountOn(DateTime(month.year, month.month, day)),
          reduceSpoken: reduceSpoken,
          onTap: onDayTap,
        ),
    ];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
            ),
            Expanded(
              child: Center(
                child: Text(
                  formatMonthYear(month),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              onPressed: onJumpToToday,
              icon: const Icon(Icons.today_outlined),
              tooltip: 'Jump to today',
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // r3a: horizontal drag switches month, alongside the chevrons.
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < 0) {
              onNext?.call();
            } else if (v > 0) {
              onPrev();
            }
          },
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.period,
    required this.flow,
    required this.symptomCount,
    required this.reduceSpoken,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final Period? period;
  final DailyFlow? flow;
  final int symptomCount;
  final bool reduceSpoken;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inPeriod = period != null;
    final isToday = dateOnly(date) == dateOnly(today);
    final f = flow;

    final hasEntries = inPeriod || f != null || symptomCount > 0;
    final parts = <String>[
      inPeriod ? 'period day' : 'no period logged',
      if (f != null) flowSemantics(f.intensity, f.clotSize),
      if (symptomCount > 0) symptomCountLabel(symptomCount),
    ];
    final semantic = reduceSpoken
        ? (hasEntries ? '${formatDay(date)}, has entries' : formatDay(date))
        : '${formatDay(date)}, ${parts.join(', ')}';

    final barColor = inPeriod
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onTap(date),
        radius: 24,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: inPeriod ? theme.colorScheme.primaryContainer : null,
              border: isToday
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: inPeriod
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                if (f != null) ...[
                  const SizedBox(height: 2),
                  _FlowBar(
                    intensity: f.intensity,
                    hasClot: f.clotSize != null,
                    color: barColor,
                  ),
                ],
                if (symptomCount > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inPeriod
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A four-segment strength bar for the day cell; segments up to the intensity
/// level are filled, plus a dot when clots were noted.
class _FlowBar extends StatelessWidget {
  const _FlowBar({
    required this.intensity,
    required this.hasClot,
    required this.color,
  });

  final FlowIntensity intensity;
  final bool hasClot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final filled = intensity.index + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < FlowIntensity.values.length; i++)
          Container(
            width: 4,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: i < filled ? color : color.withValues(alpha: 0.25),
            ),
          ),
        if (hasClot)
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
      ],
    );
  }
}

/// One history row: the period's range + a two-line detail, tapping through to
/// the day-log sheet, with a delete affordance in the trailing slot.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.period,
    required this.today,
    required this.cycle,
    required this.pcosMode,
    required this.perimenopauseMode,
    required this.onOpen,
    required this.onDelete,
  });

  final Period period;
  final DateTime today;
  final Cycle? cycle;
  final bool pcosMode;
  final bool perimenopauseMode;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cycle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(formatRange(period.startDate, period.endDate)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatLength(period.startDate, period.endDate, today)),
          if (c != null)
            Text(
              cycleLengthNote(
                c,
                pcosMode: pcosMode,
                perimenopauseMode: perimenopauseMode,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete period',
      ),
      onTap: onOpen,
    );
  }
}

/// Transient "your update was taken in" note (p3.3).
class _CorrectionNotice extends StatefulWidget {
  const _CorrectionNotice({
    required this.delta,
    required this.reduceSpoken,
    required this.onDismiss,
  });

  final PredictionDelta delta;
  final bool reduceSpoken;
  final VoidCallback onDismiss;

  @override
  State<_CorrectionNotice> createState() => _CorrectionNoticeState();
}

class _CorrectionNoticeState extends State<_CorrectionNotice> {
  static const _visibleFor = Duration(seconds: 10);
  Timer? _autoClear;

  static const _reducedLabel = 'Your prediction was updated.';

  String get _spokenLabel =>
      widget.reduceSpoken ? _reducedLabel : widget.delta.reasons.join(' ');

  @override
  void initState() {
    super.initState();
    _restartTimer();
    _announce();
  }

  @override
  void didUpdateWidget(_CorrectionNotice old) {
    super.didUpdateWidget(old);
    if (widget.delta != old.delta) {
      _restartTimer();
      _announce();
    }
  }

  @override
  void dispose() {
    _autoClear?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _autoClear?.cancel();
    _autoClear = Timer(_visibleFor, widget.onDismiss);
  }

  void _announce() {
    if (!mounted) return;
    announce(context, _spokenLabel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      liveRegion: true,
      label: _spokenLabel,
      // Neutral theme `Card` — one accent per screen, held by the forecast
      // card. This transient notice reads via its icon + live announcement.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: onColor,
                ),
              ),
              Expanded(
                // The outer Semantics already speaks the full `_spokenLabel`;
                // exclude the visual reason lines so it stays one node (the
                // theme `Card` boundary would otherwise split them out).
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.delta.reasons.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        Text(
                          widget.delta.reasons[i],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: onColor,
                tooltip: correctionNoticeDismissLabel,
                onPressed: widget.onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gentle heads-up shown after a recorded pregnancy loss / birth while cycles
/// have not resumed (p1.11).
class _PregnancyStatusCard extends ConsumerWidget {
  const _PregnancyStatusCard({required this.state, required this.since});

  final PregnancyRecoveryState state;
  final DateTime? since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final message = pregnancyBanner(state, since);
    final postpartumMode =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.postpartum))
            .valueOrNull ??
        false;

    return Semantics(
      container: true,
      label: message,
      // Neutral theme `Card` (was a hand-rolled radius-12 container); the
      // leading icon carries the state, not a coloured background.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    state == PregnancyRecoveryState.postpartum
                        ? Icons.child_friendly_outlined
                        : Icons.favorite_border,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (postpartumMode)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PostpartumScreen(),
                      ),
                    ),
                    child: const Text('Open postpartum view'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
