import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'flow_format.dart';
import 'flow_providers.dart';

/// Open the one/two-tap flow quick-log sheet for [date].
///
/// Every choice persists immediately (upsert) — there is no Save button, so
/// logging flow is *one* tap to open plus *one* tap to pick an intensity. When
/// [onEditPeriodDates] is given (the day belongs to a period) the sheet offers
/// a button that closes it and opens the period-dates editor.
Future<void> showFlowQuickLog(
  BuildContext context, {
  required DateTime date,
  VoidCallback? onEditPeriodDates,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _FlowQuickLogSheet(date: date, onEditPeriodDates: onEditPeriodDates),
  );
}

class _FlowQuickLogSheet extends ConsumerStatefulWidget {
  const _FlowQuickLogSheet({required this.date, this.onEditPeriodDates});

  final DateTime date;
  final VoidCallback? onEditPeriodDates;

  @override
  ConsumerState<_FlowQuickLogSheet> createState() => _FlowQuickLogSheetState();
}

class _FlowQuickLogSheetState extends ConsumerState<_FlowQuickLogSheet> {
  FlowIntensity? _intensity;
  ClotSize? _clot;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await ref
        .read(dailyFlowRepositoryProvider)
        .flowOn(widget.date);
    if (!mounted) return;
    setState(() {
      _intensity = existing?.intensity;
      _clot = existing?.clotSize;
      _loaded = true;
    });
  }

  void _persist() {
    final intensity = _intensity;
    if (intensity == null) return;
    ref
        .read(dailyFlowRepositoryProvider)
        .setFlow(widget.date, intensity: intensity, clotSize: _clot);
  }

  void _pickIntensity(FlowIntensity value) {
    setState(() => _intensity = value);
    _persist();
  }

  void _pickClot(ClotSize? value) {
    setState(() => _clot = value);
    _persist();
  }

  Future<void> _remove() async {
    await ref.read(dailyFlowRepositoryProvider).clearFlow(widget.date);
    if (mounted) Navigator.of(context).pop();
  }

  void _editDates() {
    Navigator.of(context).pop();
    widget.onEditPeriodDates?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Flow — ${formatDay(widget.date)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Intensity', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final value in FlowIntensity.values)
                  ChoiceChip(
                    label: Text(value.label),
                    selected: _intensity == value,
                    onSelected: (_) => _pickIntensity(value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Clots (optional)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: _intensity == null
                    ? theme.colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: _loaded && _intensity != null && _clot == null,
                  onSelected: _intensity == null
                      ? null
                      : (_) => _pickClot(null),
                ),
                for (final value in ClotSize.values)
                  ChoiceChip(
                    label: Text('${value.label} clots'),
                    selected: _clot == value,
                    onSelected: _intensity == null
                        ? null
                        : (_) => _pickClot(value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_loaded && _intensity != null)
                  TextButton.icon(
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                const Spacer(),
                if (widget.onEditPeriodDates != null)
                  TextButton(
                    onPressed: _editDates,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Edit period dates'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
