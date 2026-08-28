import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'period_format.dart';
import 'period_providers.dart';

/// What the editor did, reported back to the caller so it can show feedback.
enum PeriodEditorOutcome { saved, deleted }

/// Open the add / edit period sheet.
///
/// Pass [existing] to edit a logged period (adds a Delete action); pass
/// [initialStart] to seed the start date when adding (e.g. the calendar day the
/// user tapped). Returns `null` if dismissed without a change.
Future<PeriodEditorOutcome?> showPeriodEditor(
  BuildContext context, {
  Period? existing,
  DateTime? initialStart,
}) {
  return showModalBottomSheet<PeriodEditorOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _PeriodEditorSheet(existing: existing, initialStart: initialStart),
  );
}

class _PeriodEditorSheet extends ConsumerStatefulWidget {
  const _PeriodEditorSheet({this.existing, this.initialStart});

  final Period? existing;
  final DateTime? initialStart;

  @override
  ConsumerState<_PeriodEditorSheet> createState() => _PeriodEditorSheetState();
}

class _PeriodEditorSheetState extends ConsumerState<_PeriodEditorSheet> {
  late DateTime _start;
  DateTime? _end;
  PeriodValidationError? _serverError;
  bool _busy = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _start = dateOnly(existing.startDate);
      _end = existing.endDate == null ? null : dateOnly(existing.endDate!);
    } else {
      _start = dateOnly(widget.initialStart ?? DateTime.now());
      _end = null;
    }
  }

  PeriodDraft get _draft => PeriodDraft(start: _start, end: _end);

  PeriodValidationError? _errorAgainst(List<Period> periods) => validatePeriod(
    _draft,
    existing: periods,
    today: DateTime.now(),
    editingId: widget.existing?.id,
  );

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Period start date',
    );
    if (picked == null) return;
    setState(() {
      _start = dateOnly(picked);
      _serverError = null;
      if (_end != null && _end!.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: now,
      helpText: 'Period end date',
    );
    if (picked == null) return;
    setState(() {
      _end = dateOnly(picked);
      _serverError = null;
    });
  }

  void _toggleHasEnded(bool hasEnded) {
    setState(() {
      _end = hasEnded ? _start : null;
      _serverError = null;
    });
  }

  Future<void> _save() async {
    final repo = ref.read(periodRepositoryProvider);
    setState(() => _busy = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repo.addPeriod(_draft);
      } else {
        await repo.updatePeriod(existing.id, _draft);
      }
      if (mounted) Navigator.of(context).pop(PeriodEditorOutcome.saved);
    } on PeriodValidationException catch (e) {
      if (mounted) setState(() => _serverError = e.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this period?'),
        content: const Text('This removes the entry. You can add it again.'),
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
    if (confirmed != true) return;
    final repo = ref.read(periodRepositoryProvider);
    await repo.deletePeriod(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(PeriodEditorOutcome.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periods = ref.watch(periodsProvider).value ?? const <Period>[];
    final error = _serverError ?? _errorAgainst(periods);
    final canSave = !_busy && error == null;

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
              _isEditing ? 'Edit period' : 'Log a period',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DateRow(
              label: 'Start',
              value: formatDay(_start),
              onTap: _pickStart,
              semanticLabel: 'Start date, ${formatDay(_start)}. Change',
            ),
            const Divider(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('This period has ended'),
              value: _end != null,
              onChanged: _toggleHasEnded,
            ),
            if (_end != null) ...[
              _DateRow(
                label: 'End',
                value: formatDay(_end!),
                onTap: _pickEnd,
                semanticLabel: 'End date, ${formatDay(_end!)}. Change',
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No end date yet — you can add one later.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error.describe(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.bodyLarge),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
