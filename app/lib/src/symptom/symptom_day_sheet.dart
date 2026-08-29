import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'manage_symptoms_page.dart';
import 'symptom_providers.dart';

/// Open the low-friction symptom day sheet for [date].
///
/// One tap opens it, then one tap per symptom — every toggle persists
/// immediately, there is no Save button. [onStartPeriod] (given when the day is
/// not already part of a period) adds a shortcut that closes the sheet and
/// opens the period editor, so the p1.1 "tap an empty day to start a period"
/// affordance survives.
Future<void> showSymptomDaySheet(
  BuildContext context, {
  required DateTime date,
  VoidCallback? onStartPeriod,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SymptomDaySheet(date: date, onStartPeriod: onStartPeriod),
  );
}

class _SymptomDaySheet extends ConsumerStatefulWidget {
  const _SymptomDaySheet({required this.date, this.onStartPeriod});

  final DateTime date;
  final VoidCallback? onStartPeriod;

  @override
  ConsumerState<_SymptomDaySheet> createState() => _SymptomDaySheetState();
}

class _SymptomDaySheetState extends ConsumerState<_SymptomDaySheet> {
  final Set<int> _selected = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final present = await ref
        .read(symptomRepositoryProvider)
        .symptomsOn(widget.date);
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(present);
      _loaded = true;
    });
  }

  void _toggle(int typeId, bool present) {
    setState(() {
      if (present) {
        _selected.add(typeId);
      } else {
        _selected.remove(typeId);
      }
    });
    ref
        .read(symptomRepositoryProvider)
        .setSymptom(widget.date, typeId, present: present);
  }

  void _openManage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ManageSymptomsPage()));
  }

  void _startPeriod() {
    Navigator.of(context).pop();
    widget.onStartPeriod?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types =
        ref.watch(symptomTypesProvider).value ?? const <SymptomType>[];

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
              'Symptoms — ${formatDay(widget.date)}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap everything that applies.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (types.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _loaded
                      ? 'Your symptom list is empty. Add one to start logging.'
                      : 'Loading your symptoms…',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final type in types)
                    FilterChip(
                      label: Text(type.name),
                      selected: _selected.contains(type.id),
                      onSelected: (v) => _toggle(type.id, v),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _openManage,
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage symptoms'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                const Spacer(),
                if (widget.onStartPeriod != null)
                  TextButton(
                    onPressed: _startPeriod,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Start a period'),
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
