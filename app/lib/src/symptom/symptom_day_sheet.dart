import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_format.dart';
import '../bbt/bbt_providers.dart';
import '../mucus/mucus_providers.dart';
import '../period/period_format.dart';
import '../settings/settings_providers.dart';
import 'manage_symptoms_page.dart';
import 'symptom_providers.dart';

/// Open the low-friction day-log sheet for [date].
///
/// One tap opens it, then one tap per symptom / mucus quality — every choice
/// persists immediately, there is no Save button. Basal temperature takes a
/// short number dialog. [onStartPeriod] (given when the day is not already part
/// of a period) adds a shortcut that closes the sheet and opens the period
/// editor, so the p1.1 "tap an empty day to start a period" affordance survives.
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
  double? _tempCelsius;
  CervicalMucusType? _mucus;
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
    final bbt = await ref.read(bbtRepositoryProvider).tempOn(widget.date);
    final mucus = await ref
        .read(cervicalMucusRepositoryProvider)
        .mucusOn(widget.date);
    if (!mounted) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(present);
      _tempCelsius = bbt?.tempCelsius;
      _mucus = mucus?.type;
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

  void _pickMucus(CervicalMucusType type) {
    final next = _mucus == type ? null : type;
    setState(() => _mucus = next);
    final repo = ref.read(cervicalMucusRepositoryProvider);
    if (next == null) {
      repo.clearMucus(widget.date);
    } else {
      repo.setMucus(widget.date, next);
    }
  }

  Future<void> _editTemp(TemperatureUnit unit) async {
    final result = await showDialog<_TempResult>(
      context: context,
      builder: (_) => _TempDialog(
        date: widget.date,
        unit: unit,
        currentCelsius: _tempCelsius,
      ),
    );
    if (result == null || !mounted) return;

    final repo = ref.read(bbtRepositoryProvider);
    if (result.cleared) {
      await repo.clearTemp(widget.date);
      if (mounted) setState(() => _tempCelsius = null);
      return;
    }
    if (result.unit != unit) {
      await ref
          .read(settingsRepositoryProvider)
          .set(SettingKeys.temperatureUnit, result.unit.storageKey);
    }
    final celsius = result.celsius!;
    await repo.setTemp(widget.date, celsius);
    if (mounted) setState(() => _tempCelsius = celsius);
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
    final unit =
        ref.watch(temperatureUnitProvider).value ?? TemperatureUnit.celsius;
    final temp = _tempCelsius;

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
              'Day log — ${formatDay(widget.date)}',
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
            Text('Symptoms', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
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
            Text('Temperature & fluid', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.thermostat_outlined, size: 18),
                label: Text(
                  temp == null
                      ? 'Add basal temperature'
                      : 'Basal temp: ${formatTemp(temp, unit)}',
                ),
                onPressed: () => _editTemp(unit),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cervical fluid',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in CervicalMucusType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _mucus == type,
                    onSelected: (_) => _pickMucus(type),
                  ),
              ],
            ),
            if (_mucus != null) ...[
              const SizedBox(height: 4),
              Text(
                _mucus!.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // p5.1b: OverflowBar keeps these on one row at normal text size and
            // stacks them vertically once the labels no longer fit (large
            // Dynamic Type), instead of a Row that overflows on the right.
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.start,
              spacing: 8,
              overflowSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _openManage,
                  icon: const Icon(Icons.tune),
                  label: const Text('Manage symptoms'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    if (widget.onStartPeriod != null)
                      TextButton(
                        onPressed: _startPeriod,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Start a period'),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What [_TempDialog] returns: either a new reading (`celsius` + the `unit` it
/// was entered in) or a request to clear the day's reading.
class _TempResult {
  const _TempResult.value(this.celsius, this.unit) : cleared = false;
  const _TempResult.cleared()
    : celsius = null,
      unit = TemperatureUnit.celsius,
      cleared = true;

  final double? celsius;
  final TemperatureUnit unit;
  final bool cleared;
}

class _TempDialog extends StatefulWidget {
  const _TempDialog({
    required this.date,
    required this.unit,
    required this.currentCelsius,
  });

  final DateTime date;
  final TemperatureUnit unit;
  final double? currentCelsius;

  @override
  State<_TempDialog> createState() => _TempDialogState();
}

class _TempDialogState extends State<_TempDialog> {
  late TemperatureUnit _unit = widget.unit;
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentCelsius == null
        ? ''
        : _fieldText(widget.currentCelsius!, widget.unit),
  );

  static String _fieldText(double celsius, TemperatureUnit unit) =>
      convertFromCelsius(
        celsius,
        unit,
      ).toStringAsFixed(unit == TemperatureUnit.celsius ? 2 : 1);

  double? get _parsed => double.tryParse(_controller.text.trim());

  BbtError? get _error {
    final v = _parsed;
    if (v == null) return null; // don't shout before a full number is typed
    return validateCelsius(toCelsius(v, _unit));
  }

  bool get _canSave => _parsed != null && _error == null;

  void _switchUnit(TemperatureUnit to) {
    if (to == _unit) return;
    final shown = _parsed;
    final from = _unit;
    setState(() {
      _unit = to;
      if (shown != null) {
        _controller.text = _fieldText(toCelsius(shown, from), to);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Basal temperature — ${formatDay(widget.date)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TemperatureUnit>(
            segments: const [
              ButtonSegment(value: TemperatureUnit.celsius, label: Text('°C')),
              ButtonSegment(
                value: TemperatureUnit.fahrenheit,
                label: Text('°F'),
              ),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => _switchUnit(s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Reading (${_unit.symbol})',
              errorText: _error?.describe(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (widget.currentCelsius != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _TempResult.cleared()),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canSave
              ? () => Navigator.of(
                  context,
                ).pop(_TempResult.value(toCelsius(_parsed!, _unit), _unit))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
