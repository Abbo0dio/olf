import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'pregnancy_format.dart';
import 'pregnancy_providers.dart';

/// Record a pregnancy loss or birth, and remove one (p1.11).
///
/// Deliberately its own screen, reached from Settings — sensitive, and separate
/// from day-to-day logging. Recording an event here is what stops the cycle
/// engine treating the pregnancy gap as one long normal cycle.
class PregnancyEventsPage extends ConsumerWidget {
  const PregnancyEventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(pregnancyEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pregnancy loss & birth')),
      body: switch (eventsAsync) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              'Recording a loss or a birth tells olf to stop treating the gap '
              'as one long cycle. Estimates pause and then come back gently as '
              'you log periods again. You can remove an entry any time.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (value.isEmpty)
              Text(
                'Nothing recorded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final event in value.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    event.kind == PregnancyEndKind.birth
                        ? Icons.child_friendly_outlined
                        : Icons.favorite_border,
                  ),
                  title: Text(pregnancyEndKindLabel(event.kind)),
                  subtitle: Text(pregnancyEventDate(event)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove',
                    onPressed: () => _confirmRemove(context, ref, event),
                  ),
                ),
          ],
        ),
        AsyncError() => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not read your entries.'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result =
        await showModalBottomSheet<({PregnancyEndKind kind, DateTime date})>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => const _AddSheet(),
        );
    if (result == null) return;
    await ref
        .read(cycleEventRepositoryProvider)
        .logPregnancyEnd(result.kind, result.date);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PregnancyEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this entry?'),
        content: Text(
          'olf will go back to treating '
          '${pregnancyEventSummary(event)} as part of a normal cycle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(cycleEventRepositoryProvider).deleteEvent(event.id);
    messenger.showSnackBar(const SnackBar(content: Text('Entry removed.')));
  }
}

/// Pick a kind and a date. Returns the pair, or `null` on dismiss.
class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  PregnancyEndKind _kind = PregnancyEndKind.loss;
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Date it happened',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add an entry', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<PregnancyEndKind>(
              segments: [
                for (final k in PregnancyEndKind.values)
                  ButtonSegment(
                    value: k,
                    label: Text(pregnancyEndKindLabel(k)),
                  ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date'),
              subtitle: Text(_longDate(_date)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((kind: _kind, date: _date)),
              child: const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _longDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
