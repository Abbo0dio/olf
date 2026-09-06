import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'pregnancy_mode_format.dart';

/// Pick a pregnancy start reference — which kind of date, and the date itself
/// (p7.2a). Returns the chosen [PregnancyStartReference], or `null` on dismiss.
Future<PregnancyStartReference?> showPregnancyStartSheet(
  BuildContext context, {
  PregnancyStartReference? initial,
}) => showModalBottomSheet<PregnancyStartReference>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _PregnancyStartSheet(initial: initial),
);

/// Widest look-back for a last-period / conception date, and look-ahead for a
/// due date — a bit over a full term so an overdue or freshly-dated entry fits.
const Duration _window = Duration(days: 330);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

({DateTime first, DateTime last}) _bounds(PregnancyReferenceKind kind) {
  final today = _dateOnly(DateTime.now());
  return switch (kind) {
    PregnancyReferenceKind.dueDate => (
      first: today.subtract(const Duration(days: 60)),
      last: today.add(_window),
    ),
    _ => (first: today.subtract(_window), last: today),
  };
}

DateTime _clampToBounds(DateTime date, PregnancyReferenceKind kind) {
  final b = _bounds(kind);
  if (date.isBefore(b.first)) return b.first;
  if (date.isAfter(b.last)) return b.last;
  return date;
}

class _PregnancyStartSheet extends StatefulWidget {
  const _PregnancyStartSheet({this.initial});

  final PregnancyStartReference? initial;

  @override
  State<_PregnancyStartSheet> createState() => _PregnancyStartSheetState();
}

class _PregnancyStartSheetState extends State<_PregnancyStartSheet> {
  late PregnancyReferenceKind _kind =
      widget.initial?.kind ?? PregnancyReferenceKind.lastMenstrualPeriod;
  late DateTime _date = _clampToBounds(
    widget.initial?.date ?? _dateOnly(DateTime.now()),
    _kind,
  );

  Future<void> _pickDate() async {
    final b = _bounds(_kind);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: b.first,
      lastDate: b.last,
      helpText: referenceKindLabel(_kind),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  void _selectKind(PregnancyReferenceKind kind) {
    setState(() {
      _kind = kind;
      _date = _clampToBounds(_date, kind);
    });
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
            Text('Your start date', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pick whichever you know — olf works out the rest.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            RadioGroup<PregnancyReferenceKind>(
              groupValue: _kind,
              onChanged: (value) {
                if (value != null) _selectKind(value);
              },
              child: Column(
                children: [
                  for (final kind in PregnancyReferenceKind.values)
                    RadioListTile<PregnancyReferenceKind>(
                      value: kind,
                      contentPadding: EdgeInsets.zero,
                      title: Text(referenceKindLabel(kind)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date'),
              subtitle: Text(formatDay(_date)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(PregnancyStartReference(kind: _kind, date: _date)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
