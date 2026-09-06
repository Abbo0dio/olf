import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import 'pregnancy_mode_format.dart';
import 'pregnancy_mode_providers.dart';
import 'pregnancy_start_sheet.dart';

/// Pregnancy mode's week view (p7.2a): gestational week + trimester, a short
/// bundled development note, and the estimated due date — all derived from the
/// one start reference the user enters here. Explicitly not a medical timeline.
class PregnancyWeekScreen extends ConsumerWidget {
  const PregnancyWeekScreen({super.key});

  Future<void> _editReference(
    BuildContext context,
    WidgetRef ref,
    PregnancyStartReference? current,
  ) async {
    final picked = await showPregnancyStartSheet(context, initial: current);
    if (picked != null) {
      await setPregnancyStartReference(ref, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reference = ref.watch(pregnancyStartReferenceProvider).value;
    final ga = ref.watch(gestationalAgeProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pregnancy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (reference == null)
            _NeedsReference(onAdd: () => _editReference(context, ref, null))
          else if (ga == null)
            _ReferenceInFuture(
              reference: reference,
              onEdit: () => _editReference(context, ref, reference),
            )
          else
            ..._weekView(
              context,
              ref,
              reference: reference,
              ga: ga,
              reduceSpoken: reduceSpoken,
            ),
          const SizedBox(height: 24),
          Text(
            pregnancyModeDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _weekView(
    BuildContext context,
    WidgetRef ref, {
    required PregnancyStartReference reference,
    required GestationalAge ga,
    required bool reduceSpoken,
  }) {
    final theme = Theme.of(context);
    return [
      Text(
        gestationalAgeHeadline(ga),
        style: theme.textTheme.headlineSmall,
        semanticsLabel: spokenLabel(
          reduceSpoken,
          redacted: gestationalAgeHeadlineRedacted,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${trimesterLabel(ga.trimester)} · ${ga.compact}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        estimatedDueDateLine(reference),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pregnancyWeekViewIntro, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              pregnancyWeekNote(ga.completedWeeks),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        referenceSummaryLine(reference),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _editReference(context, ref, reference),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Change start date'),
        ),
      ),
    ];
  }
}

class _NeedsReference extends StatelessWidget {
  const _NeedsReference({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set your start date', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(pregnancyNeedsReferenceBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.event_outlined),
          label: const Text('Add start date'),
        ),
      ],
    );
  }
}

class _ReferenceInFuture extends StatelessWidget {
  const _ReferenceInFuture({required this.reference, required this.onEdit});

  final PregnancyStartReference reference;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Check your dates', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(pregnancyReferenceInFutureBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          referenceSummaryLine(reference),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Change start date'),
        ),
      ],
    );
  }
}
