import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/announce.dart';
import '../a11y/spoken_detail.dart';
import '../cycle/cycle_format.dart';
import '../cycle/cycle_providers.dart';
import '../cycle/cycle_wheel.dart';
import '../flow/flow_format.dart';
import '../flow/flow_providers.dart';
import '../bbt/bbt_chart_widget.dart';
import '../bbt/bbt_providers.dart';
import '../flow/flow_quick_log.dart';
import '../mucus/mucus_providers.dart';
import '../pregnancy/pregnancy_format.dart';
import '../pregnancy/pregnancy_providers.dart';
import '../prediction/correction_notice_providers.dart';
import '../prediction/prediction_format.dart';
import '../prediction/prediction_providers.dart';
import '../symptom/symptom_day_sheet.dart';
import '../symptom/symptom_format.dart';
import '../symptom/symptom_providers.dart';
import 'period_editor.dart';
import 'period_format.dart';
import 'period_providers.dart';

/// The home screen: a month calendar of logged periods and per-day flow, a
/// running summary, and a history list.
///
/// Tapping a **period day** opens the flow quick-log (p1.2); tapping any other
/// day opens the symptom day sheet (p1.5), which itself offers "Start a period"
/// to reach the period-dates editor (p1.1). The "Add a period" button opens
/// that editor directly. Every view watches the same streams so they stay in
/// sync.
class PeriodCalendarView extends ConsumerWidget {
  const PeriodCalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = ref.watch(periodsProvider);
    return switch (periods) {
      AsyncData(:final value) => _Loaded(periods: value),
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
  const _Loaded({required this.periods});

  final List<Period> periods;

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

  Future<void> _openForDay(DateTime day) async {
    final period = _periodOn(day);
    if (period != null) {
      // Period day → fast path: log what happened that day.
      await showFlowQuickLog(
        context,
        date: day,
        onEditPeriodDates: () => _edit(period),
        onAddSymptoms: () => _openSymptoms(day),
      );
      return;
    }
    // Any other day → the low-friction symptom sheet, which offers a shortcut
    // to start a period here.
    await _openSymptoms(day, onStartPeriod: () => _startPeriodOn(day));
  }

  Future<void> _openSymptoms(DateTime day, {VoidCallback? onStartPeriod}) {
    return showSymptomDaySheet(
      context,
      date: day,
      onStartPeriod: onStartPeriod,
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final flows = ref.watch(dailyFlowsProvider).value ?? const <DailyFlow>[];
    final flowByDay = <DateTime, DailyFlow>{
      for (final f in flows) dateOnly(f.date): f,
    };
    DailyFlow? flowOn(DateTime day) => flowByDay[dateOnly(day)];

    final cycles = ref.watch(cyclesProvider);
    final cycleStats = ref.watch(cycleStatsProvider);
    final prediction = ref.watch(predictionProvider);
    final correctionDelta = ref.watch(correctionNoticeProvider);
    final cycleByStart = <DateTime, Cycle>{
      for (final c in cycles) c.periodStart: c,
    };

    final symptomEntries =
        ref.watch(symptomEntriesProvider).value ?? const <DailySymptomEntry>[];
    final symptomTypes =
        ref.watch(symptomTypesProvider).value ?? const <SymptomType>[];
    final symptomIdsByDay = <DateTime, List<int>>{};
    for (final e in symptomEntries) {
      (symptomIdsByDay[dateOnly(e.date)] ??= <int>[]).add(e.symptomTypeId);
    }
    int symptomCountOn(DateTime day) =>
        symptomIdsByDay[dateOnly(day)]?.length ?? 0;

    final bbtEntries =
        ref.watch(bbtEntriesProvider).value ?? const <BbtEntry>[];
    final tempUnit =
        ref.watch(temperatureUnitProvider).value ?? TemperatureUnit.celsius;
    final currentCycle = cycles.isEmpty ? null : cycles.first;
    final cyclePhase = currentCyclePhase(
      cycle: currentCycle,
      prediction: prediction,
      today: today,
    );
    final bbtPoints = currentCycle == null
        ? const <BbtChartPoint>[]
        : bbtChartForCycle(currentCycle, bbtEntries);
    final observedFertile = ref.watch(observedFertileWindowProvider);
    final pregnancyState = ref.watch(pregnancyRecoveryStateProvider);
    final pregnancySince = ref.watch(mostRecentPregnancyEndProvider)?.date;

    // p5.3: when "Reduce spoken detail" is on, sensitive read-outs on this
    // screen (day cells, the prediction card, the correction notice, the
    // recent-symptoms list, today's flow chip) announce only that an entry
    // exists. Visible text is unchanged.
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CycleWheel(
            phase: cyclePhase,
            reduceSpoken: reduceSpoken,
            onTap: () => showFlowQuickLog(context, date: today),
          ),
          const SizedBox(height: 16),
          _Summary(
            periods: _periods,
            today: today,
            todayFlow: flowOn(today),
            todaySymptomCount: symptomCountOn(today),
            reduceSpoken: reduceSpoken,
            onLogTodayFlow: () => showFlowQuickLog(context, date: today),
            onLogTodaySymptoms: () => _openSymptoms(
              today,
              onStartPeriod: _periodOn(today) == null
                  ? () => _startPeriodOn(today)
                  : null,
            ),
          ),
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
          if (prediction != null) ...[
            const SizedBox(height: 16),
            _PredictionCard(
              prediction: prediction,
              observedFertileWindow: observedFertile,
              reduceSpoken: reduceSpoken,
              onLogPeriodStart: _addPeriod,
            ),
          ],
          if (_periods.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CycleStatsCard(stats: cycleStats),
          ],
          if (bbtPoints.length >= 2) ...[
            const SizedBox(height: 16),
            _BbtCard(points: bbtPoints, unit: tempUnit),
          ],
          const SizedBox(height: 24),
          _MonthCalendar(
            month: _visibleMonth,
            today: today,
            periodOn: _periodOn,
            flowOn: flowOn,
            symptomCountOn: symptomCountOn,
            reduceSpoken: reduceSpoken,
            onPrev: () =>
                setState(() => _visibleMonth = addMonths(_visibleMonth, -1)),
            onNext: _visibleMonth.isBefore(firstOfMonth(today))
                ? () => setState(
                    () => _visibleMonth = addMonths(_visibleMonth, 1),
                  )
                : null,
            onDayTap: _openForDay,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _addPeriod,
              style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
              icon: const Icon(Icons.add),
              label: const Text('Add a period'),
            ),
          ),
          const SizedBox(height: 24),
          _History(
            periods: _periods,
            today: today,
            cycleByStart: cycleByStart,
            onEdit: _edit,
            onDelete: _deleteFromHistory,
          ),
          const SizedBox(height: 24),
          _RecentSymptoms(
            idsByDay: symptomIdsByDay,
            types: symptomTypes,
            reduceSpoken: reduceSpoken,
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.periods,
    required this.today,
    required this.todayFlow,
    required this.todaySymptomCount,
    required this.reduceSpoken,
    required this.onLogTodayFlow,
    required this.onLogTodaySymptoms,
  });

  final List<Period> periods;
  final DateTime today;
  final DailyFlow? todayFlow;
  final int todaySymptomCount;
  final bool reduceSpoken;
  final VoidCallback onLogTodayFlow;
  final VoidCallback onLogTodaySymptoms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (periods.isEmpty) {
      content = Text(
        'No periods logged yet.',
        style: theme.textTheme.bodyLarge,
      );
    } else {
      final latest = periods.first;
      final ongoing =
          latest.endDate == null &&
          !dateOnly(latest.startDate).isAfter(dateOnly(today));

      if (ongoing) {
        final day = dayCountSince(latest.startDate, today);
        final flow = todayFlow;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day $day',
              style: theme.textTheme.displaySmall,
              semanticsLabel: 'Day $day of your period',
            ),
            const SizedBox(height: 4),
            Text('Period started ${formatDay(latest.startDate)}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.water_drop_outlined, size: 18),
                label: Text(
                  flow == null
                      ? "Log today's flow"
                      : "Today's flow: ${flow.intensity.label}",
                  semanticsLabel: flow == null
                      ? null
                      : spokenLabel(
                          reduceSpoken,
                          redacted: "Today's flow logged",
                        ),
                ),
                onPressed: onLogTodayFlow,
              ),
            ),
          ],
        );
      } else {
        content = Column(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.spa_outlined, size: 18),
            label: Text(
              todaySymptomCount == 0
                  ? "Log today's symptoms"
                  : "Today's symptoms: $todaySymptomCount",
              semanticsLabel: todaySymptomCount == 0
                  ? null
                  : spokenLabel(
                      reduceSpoken,
                      redacted: "Today's symptoms logged",
                    ),
            ),
            onPressed: onLogTodaySymptoms,
          ),
        ),
      ],
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
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
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
    // p5.3: with "Reduce spoken detail" on, a day with anything logged
    // announces only "<date>, has entries" — no flow intensity, symptom count,
    // or period state.
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

class _History extends StatelessWidget {
  const _History({
    required this.periods,
    required this.today,
    required this.cycleByStart,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Period> periods;
  final DateTime today;

  /// The derived cycle each period opens, keyed by `dateOnly(startDate)`.
  final Map<DateTime, Cycle> cycleByStart;
  final ValueChanged<Period> onEdit;
  final ValueChanged<Period> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (periods.isEmpty)
          Text(
            'Nothing logged yet. Tap a day or "Add a period".',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final period in periods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatRange(period.startDate, period.endDate)),
              subtitle: _HistoryRowDetail(
                periodLength: formatLength(
                  period.startDate,
                  period.endDate,
                  today,
                ),
                cycle: cycleByStart[dateOnly(period.startDate)],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => onEdit(period),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit period',
                  ),
                  IconButton(
                    onPressed: () => onDelete(period),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete period',
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The recent days that have symptoms logged, newest first, with the symptom
/// names for each. Names are resolved against the active catalogue; a symptom
/// that has since been removed drops out of the list (its day still counts on
/// the calendar).
class _RecentSymptoms extends StatelessWidget {
  const _RecentSymptoms({
    required this.idsByDay,
    required this.types,
    required this.reduceSpoken,
  });

  final Map<DateTime, List<int>> idsByDay;
  final List<SymptomType> types;
  final bool reduceSpoken;

  static const int _maxDays = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = idsByDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent symptoms', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (days.isEmpty)
          Text('No symptoms logged yet.', style: theme.textTheme.bodyMedium)
        else
          for (final day in days.take(_maxDays))
            Builder(
              builder: (context) {
                final names = symptomNames(idsByDay[day]!, types);
                if (names.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatDay(day), style: theme.textTheme.bodyMedium),
                      Text(
                        symptomSummary(names),
                        semanticsLabel: spokenLabel(
                          reduceSpoken,
                          redacted: symptomCountLabel(names.length),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}

/// A history row's two-line subtitle: the period's own length, then the cycle it
/// opened (once one can be derived).
class _HistoryRowDetail extends StatelessWidget {
  const _HistoryRowDetail({required this.periodLength, required this.cycle});

  final String periodLength;
  final Cycle? cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = cycle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(periodLength),
        if (c != null)
          Text(
            cycleLengthNote(c),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The headline forecast: the next-period and fertile windows as **ranges**
/// with a confidence note — or, when a period is late, a calm check-in that
/// does **not** roll the estimate forward (it still shows the from-last-period
/// dates and asks the user to log the real start).
class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.prediction,
    required this.onLogPeriodStart,
    required this.reduceSpoken,
    this.observedFertileWindow,
  });

  final CyclePrediction prediction;
  final VoidCallback onLogPeriodStart;
  final bool reduceSpoken;

  /// Fertile window observed from this cycle's cervical-mucus notes (p1.6).
  /// Shown as an extra line alongside the statistical estimate when present.
  final DateRange? observedFertileWindow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: prediction.isOverdue
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: prediction.isOverdue ? _overdue(context) : _forecast(context),
      ),
    );
  }

  Widget _forecast(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;
    final expected = formatDay(prediction.nextPeriodExpected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Next period',
              style: theme.textTheme.labelMedium?.copyWith(color: onColor),
            ),
            const Spacer(),
            Text(
              confidenceLabel(prediction.confidence),
              style: theme.textTheme.labelSmall?.copyWith(color: onColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDateRange(prediction.nextPeriod),
          style: theme.textTheme.titleLarge?.copyWith(color: onColor),
        ),
        const SizedBox(height: 2),
        Text(
          prediction.status == PredictionStatus.dueNow
              ? 'Expected around now — most likely $expected'
              : 'Most likely $expected',
          style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 12),
        Text(
          'Fertile window (estimate)',
          style: theme.textTheme.labelMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 2),
        Text(
          formatDateRange(prediction.fertileWindow),
          style: theme.textTheme.bodyLarge?.copyWith(color: onColor),
        ),
        if (observedFertileWindow != null) ...[
          const SizedBox(height: 4),
          Text(
            'Fertile signs (from your notes): '
            '${formatDateRange(observedFertileWindow!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          confidenceNote(prediction),
          style: theme.textTheme.bodySmall?.copyWith(color: onColor),
        ),
      ],
    );
  }

  Widget _overdue(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onTertiaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period check-in',
          style: theme.textTheme.labelMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 4),
        Text(
          overdueHeadline(prediction.daysPastExpected!),
          style: theme.textTheme.titleMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 6),
        Text(
          overdueBody,
          style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: onLogPeriodStart,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Log period start'),
          ),
        ),
      ],
    );
  }

  String _semanticLabel() {
    // p5.3: with "Reduce spoken detail" on, the forecast dates are not spoken —
    // just that a prediction is on screen.
    if (reduceSpoken) {
      return prediction.isOverdue
          ? 'Period check-in available. Open the calendar for details.'
          : 'Next period prediction available. Open the calendar for the dates.';
    }
    if (prediction.isOverdue) {
      return 'Period check-in. '
          '${overdueHeadline(prediction.daysPastExpected!)}. $overdueBody';
    }
    final signs = observedFertileWindow == null
        ? ''
        : 'Fertile signs from your notes '
              '${formatDateRange(observedFertileWindow!)}. ';
    return 'Next period estimated ${formatDateRange(prediction.nextPeriod)}, '
        'most likely ${formatDay(prediction.nextPeriodExpected)}. '
        'Fertile window estimated ${formatDateRange(prediction.fertileWindow)}. '
        '$signs${confidenceNote(prediction)}';
  }
}

/// Transient "your update was taken in" note (p3.3).
///
/// Shown right where the prediction card is (or would be) after the user edits,
/// adds, or deletes a logged period. Its body is [PredictionDelta.reasons]
/// verbatim — plain-language, gender-neutral, non-alarming lines produced by the
/// core engine, including the explicit "did not need to change" line when the
/// forecast held. It is a live change, so it announces itself to screen readers
/// and clears on its own after a short while (or on manual dismiss).
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

  /// p5.3: the reason lines can name dates, so with "Reduce spoken detail" on
  /// the screen reader hears only that the forecast changed. Visible text is
  /// unchanged.
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
    final onColor = theme.colorScheme.onSecondaryContainer;
    return Semantics(
      container: true,
      liveRegion: true,
      label: _spokenLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(Icons.check_circle_outline, size: 20, color: onColor),
            ),
            Expanded(
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
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: onColor,
              tooltip: correctionNoticeDismissLabel,
              onPressed: widget.onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cycle-length and variability summary, shown once at least one period exists.
/// Falls back to a "keep logging" nudge rather than assuming any cycle length.
class _CycleStatsCard extends StatelessWidget {
  const _CycleStatsCard({required this.stats});

  final CycleStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typical = stats.typicalCycleLength;
    final hasRange = stats.shortestCycleLength != stats.longestCycleLength;

    return Semantics(
      container: true,
      label: 'Cycle insights. ${summariseStats(stats)}',
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
            Text(
              'Your cycles',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            if (typical != null) ...[
              Text(
                '$typical-day typical cycle',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                hasRange
                    ? '${stats.shortestCycleLength}–${stats.longestCycleLength} '
                          'days  ·  ${stats.regularity.label}'
                    : stats.regularity.label,
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
                  'A long gap is set aside — a period may not have been logged '
                  'then.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else
              Text(summariseStats(stats), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// This cycle's basal-temperature chart, shown once there are at least two
/// readings to draw a line between.
class _BbtCard extends StatelessWidget {
  const _BbtCard({required this.points, required this.unit});

  final List<BbtChartPoint> points;
  final TemperatureUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basal temperature — this cycle',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          BbtChart(points: points, unit: unit),
        ],
      ),
    );
  }
}

/// Gentle heads-up shown after a recorded pregnancy loss / birth while cycles
/// have not resumed (p1.11). Explains why estimates are paused.
class _PregnancyStatusCard extends StatelessWidget {
  const _PregnancyStatusCard({required this.state, required this.since});

  final PregnancyRecoveryState state;
  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = pregnancyBanner(state, since);

    return Semantics(
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              state == PregnancyRecoveryState.postpartum
                  ? Icons.child_friendly_outlined
                  : Icons.favorite_border,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
