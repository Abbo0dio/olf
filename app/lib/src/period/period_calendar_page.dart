import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../flow/flow_format.dart';
import '../flow/flow_providers.dart';
import '../flow/flow_quick_log.dart';
import 'period_editor.dart';
import 'period_format.dart';
import 'period_providers.dart';

/// The home screen: a month calendar of logged periods and per-day flow, a
/// running summary, and a history list.
///
/// Tapping a **period day** opens the flow quick-log (p1.2); tapping an empty
/// day, or the "Add a period" button, opens the period-dates editor (p1.1).
/// Every view watches the same two streams so they stay in sync.
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
      );
      return;
    }
    // Empty day → log a new period starting here.
    _reportOutcome(await showPeriodEditor(context, initialStart: day));
  }

  Future<void> _addPeriod() async {
    _reportOutcome(
      await showPeriodEditor(context, initialStart: DateTime.now()),
    );
  }

  Future<void> _edit(Period period) async {
    _reportOutcome(await showPeriodEditor(context, existing: period));
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
    await repo.deletePeriod(period.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Period deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.addPeriod(restore),
        ),
      ),
    );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(
            periods: _periods,
            today: today,
            todayFlow: flowOn(today),
            onLogTodayFlow: () => showFlowQuickLog(context, date: today),
          ),
          const SizedBox(height: 24),
          _MonthCalendar(
            month: _visibleMonth,
            today: today,
            periodOn: _periodOn,
            flowOn: flowOn,
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
            onEdit: _edit,
            onDelete: _deleteFromHistory,
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
    required this.onLogTodayFlow,
  });

  final List<Period> periods;
  final DateTime today;
  final DailyFlow? todayFlow;
  final VoidCallback onLogTodayFlow;

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
      final flow = todayFlow;
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.water_drop_outlined, size: 18),
              label: Text(
                flow == null
                    ? "Log today's flow"
                    : "Today's flow: ${flow.intensity.label}",
              ),
              onPressed: onLogTodayFlow,
            ),
          ),
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.periodOn,
    required this.flowOn,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime today;
  final Period? Function(DateTime) periodOn;
  final DailyFlow? Function(DateTime) flowOn;
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
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final Period? period;
  final DailyFlow? flow;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inPeriod = period != null;
    final isToday = dateOnly(date) == dateOnly(today);
    final f = flow;

    final parts = <String>[
      inPeriod ? 'period day' : 'no period logged',
      if (f != null) flowSemantics(f.intensity, f.clotSize),
    ];
    final semantic = '${formatDay(date)}, ${parts.join(', ')}';

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
    required this.onEdit,
    required this.onDelete,
  });

  final List<Period> periods;
  final DateTime today;
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
              subtitle: Text(
                formatLength(period.startDate, period.endDate, today),
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
