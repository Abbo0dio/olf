import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../bbt/bbt_format.dart';
import '../bbt/bbt_providers.dart';
import '../flow/flow_format.dart';
import '../flow/flow_providers.dart';
import '../health/health_providers.dart';
import '../modes/endometriosis_pain_sheet.dart';
import '../modes/modes_providers.dart';
import '../modes/pmdd_rating_sheet.dart';
import '../mucus/mucus_providers.dart';
import '../period/period_format.dart';
import '../settings/settings_providers.dart';
import '../symptom/manage_symptoms_page.dart';
import '../symptom/symptom_providers.dart';

/// Which section opens expanded when the sheet is shown. `null` (the default)
/// derives it from the day: [DayLogLead.flow] for a period day or today,
/// [DayLogLead.symptoms] otherwise.
enum DayLogLead { flow, symptoms }

/// Open the one unified day-log sheet for [date] (r2 — replaces the old
/// `showFlowQuickLog` + `showSymptomDaySheet`).
///
/// Sections: Flow · Symptoms · Temperature · Cervical fluid, plus a per-mode
/// quick-input section for any enabled life-stage/condition mode that has one
/// (PMDD, endometriosis). Exactly one section is expanded on open (see
/// [DayLogLead]); the rest are collapsed so an unmodded, nothing-logged sheet
/// is not a wall of controls. Every choice upserts immediately — no Save button
/// on Flow / Symptoms / Temperature / Fluid.
///
/// [onEditPeriodDates] is given exactly when [date] is a period day (adds an
/// "Edit period dates" action); [onStartPeriod] is given otherwise (adds a
/// "Start a period" action). Both close the sheet first.
Future<void> showDayLog(
  BuildContext context, {
  required DateTime date,
  DayLogLead? lead,
  VoidCallback? onEditPeriodDates,
  VoidCallback? onStartPeriod,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DayLogSheet(
      date: date,
      lead: lead,
      onEditPeriodDates: onEditPeriodDates,
      onStartPeriod: onStartPeriod,
    ),
  );
}

class _DayLogSheet extends ConsumerStatefulWidget {
  const _DayLogSheet({
    required this.date,
    this.lead,
    this.onEditPeriodDates,
    this.onStartPeriod,
  });

  final DateTime date;
  final DayLogLead? lead;
  final VoidCallback? onEditPeriodDates;
  final VoidCallback? onStartPeriod;

  @override
  ConsumerState<_DayLogSheet> createState() => _DayLogSheetState();
}

class _DayLogSheetState extends ConsumerState<_DayLogSheet> {
  // Flow.
  FlowIntensity? _intensity;
  ClotSize? _clot;
  // Symptoms.
  final Set<int> _selected = {};
  // Temperature (p8.1a: `_tempKind` drives the passive-source sub-label).
  double? _tempCelsius;
  BbtMeasurementKind? _tempKind;
  // Cervical fluid.
  CervicalMucusType? _mucus;

  bool _loaded = false;

  bool get _isPeriodDay => widget.onEditPeriodDates != null;

  bool get _isToday => dateOnly(widget.date) == dateOnly(DateTime.now());

  DayLogLead get _lead =>
      widget.lead ??
      ((_isPeriodDay || _isToday) ? DayLogLead.flow : DayLogLead.symptoms);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final flow = await ref
        .read(dailyFlowRepositoryProvider)
        .flowOn(widget.date);
    final present = await ref
        .read(symptomRepositoryProvider)
        .symptomsOn(widget.date);
    final bbt = await ref.read(bbtRepositoryProvider).tempOn(widget.date);
    final mucus = await ref
        .read(cervicalMucusRepositoryProvider)
        .mucusOn(widget.date);
    if (!mounted) return;
    setState(() {
      _intensity = flow?.intensity;
      _clot = flow?.clotSize;
      _selected
        ..clear()
        ..addAll(present);
      _tempCelsius = bbt?.tempCelsius;
      _tempKind = bbt?.measurementKind;
      _mucus = mucus?.type;
      _loaded = true;
    });
  }

  // --- Flow -----------------------------------------------------------------

  Future<void> _persistFlow() async {
    final intensity = _intensity;
    if (intensity == null) return;
    await ref
        .read(dailyFlowRepositoryProvider)
        .setFlow(widget.date, intensity: intensity, clotSize: _clot);
    // p6.4: mirror the entry out to a connected health platform. Fire-and-
    // forget — never blocks or fails the log.
    if (!mounted) return;
    await writeBackFlow(ref, widget.date);
  }

  void _pickIntensity(FlowIntensity value) {
    setState(() => _intensity = value);
    _persistFlow();
  }

  void _pickClot(ClotSize? value) {
    setState(() => _clot = value);
    _persistFlow();
  }

  Future<void> _removeFlow() async {
    await ref.read(dailyFlowRepositoryProvider).clearFlow(widget.date);
    if (!mounted) return;
    setState(() {
      _intensity = null;
      _clot = null;
    });
  }

  // --- Symptoms -----------------------------------------------------------

  void _toggleSymptom(int typeId, bool present) {
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

  // --- Temperature ------------------------------------------------------

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
      if (mounted) {
        setState(() {
          _tempCelsius = null;
          _tempKind = null;
        });
      }
      return;
    }
    if (result.unit != unit) {
      await ref
          .read(settingsRepositoryProvider)
          .set(SettingKeys.temperatureUnit, result.unit.storageKey);
    }
    final celsius = result.celsius!;
    // A typed correction always writes a basal reading — even when it is
    // replacing a passive Apple Watch value (p8.1a).
    await repo.setTemp(widget.date, celsius);
    if (!mounted) return;
    setState(() {
      _tempCelsius = celsius;
      _tempKind = BbtMeasurementKind.basal;
    });
    // p6.4: mirror the reading out. Fire-and-forget.
    await writeBackBbt(ref, widget.date);
  }

  // --- Cervical fluid --------------------------------------------------

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

  // --- Period actions -------------------------------------------------

  void _editDates() {
    Navigator.of(context).pop();
    widget.onEditPeriodDates?.call();
  }

  void _startPeriod() {
    Navigator.of(context).pop();
    widget.onStartPeriod?.call();
  }

  // --- Build -----------------------------------------------------------

  ExpansionTile _section({
    required String title,
    required bool initiallyExpanded,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.labelLarge),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types =
        ref.watch(symptomTypesProvider).value ?? const <SymptomType>[];
    final unit =
        ref.watch(temperatureUnitProvider).value ?? TemperatureUnit.celsius;
    // p5.3: with "Reduce spoken detail" on, chip names are not spoken — the
    // screen reader still announces the selected state, and the visible label
    // is unchanged.
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
    final pmddOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.pmdd))
            .valueOrNull ??
        false;
    final endoOn =
        ref
            .watch(lifeStageModeEnabledProvider(LifeStageMode.endometriosis))
            .valueOrNull ??
        false;

    final lead = _lead;

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
            const SizedBox(height: 8),
            _section(
              title: 'Flow',
              initiallyExpanded: lead == DayLogLead.flow,
              children: _flowChildren(theme),
            ),
            _section(
              title: 'Symptoms',
              initiallyExpanded: lead == DayLogLead.symptoms,
              children: _symptomChildren(theme, types, reduceSpoken),
            ),
            _section(
              title: 'Temperature',
              initiallyExpanded: false,
              children: _tempChildren(theme, unit, reduceSpoken),
            ),
            _section(
              title: 'Cervical fluid',
              initiallyExpanded: false,
              children: _fluidChildren(theme),
            ),
            if (pmddOn)
              _section(
                title: 'PMDD rating',
                initiallyExpanded: false,
                children: const [PmddRatingBody()],
              ),
            if (endoOn)
              _section(
                title: 'Pain & flares',
                initiallyExpanded: false,
                children: const [EndometriosisPainBody()],
              ),
            const SizedBox(height: 16),
            // p5.1b: OverflowBar keeps these on one row at normal text size and
            // stacks them once the labels no longer fit (large Dynamic Type).
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
                    if (widget.onEditPeriodDates != null)
                      TextButton(
                        onPressed: _editDates,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Edit period dates'),
                      ),
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

  List<Widget> _flowChildren(ThemeData theme) => [
    Text('Intensity', style: theme.textTheme.labelMedium),
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
      style: theme.textTheme.labelMedium?.copyWith(
        color: _intensity == null ? theme.colorScheme.onSurfaceVariant : null,
      ),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('None'),
          selected: _loaded && _intensity != null && _clot == null,
          onSelected: _intensity == null ? null : (_) => _pickClot(null),
        ),
        for (final value in ClotSize.values)
          ChoiceChip(
            label: Text('${value.label} clots'),
            selected: _clot == value,
            onSelected: _intensity == null ? null : (_) => _pickClot(value),
          ),
      ],
    ),
    if (_loaded && _intensity != null) ...[
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _removeFlow,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            minimumSize: const Size(0, 48),
          ),
        ),
      ),
    ],
  ];

  List<Widget> _symptomChildren(
    ThemeData theme,
    List<SymptomType> types,
    bool reduceSpoken,
  ) => [
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
              label: Text(
                type.name,
                semanticsLabel: spokenLabel(reduceSpoken, redacted: 'symptom'),
              ),
              selected: _selected.contains(type.id),
              onSelected: (v) => _toggleSymptom(type.id, v),
            ),
        ],
      ),
  ];

  List<Widget> _tempChildren(
    ThemeData theme,
    TemperatureUnit unit,
    bool reduceSpoken,
  ) {
    final temp = _tempCelsius;
    // p8.1a: non-null only when the stored reading is a passive Apple Watch
    // capture — shown as a sub-label under the temperature chip.
    final tempSourceLabel = temp == null
        ? null
        : bbtSourceLabel(_tempKind ?? BbtMeasurementKind.basal);
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActionChip(
              avatar: const Icon(Icons.thermostat_outlined, size: 18),
              label: Text(
                temp == null
                    ? 'Add basal temperature'
                    : 'Basal temp: ${formatTemp(temp, unit)}',
              ),
              onPressed: () => _editTemp(unit),
            ),
            // p8.1a: mark a passively-captured Apple Watch reading as distinct
            // from one the user typed. Tapping the chip corrects it (which turns
            // it into a typed basal reading).
            if (tempSourceLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  tempSourceLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  semanticsLabel: reduceSpoken
                      ? 'Passive temperature reading'
                      : tempSourceLabel,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _fluidChildren(ThemeData theme) => [
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
  ];
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
