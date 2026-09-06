import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../period/period_format.dart';
import '../symptom/manage_symptoms_page.dart';
import '../symptom/symptom_providers.dart';
import 'pregnancy_mode_format.dart';

/// A curated set of things people commonly notice during pregnancy (p7.2b).
///
/// This is **not** new storage — it is a bundled name list. When pregnancy mode
/// is on, [PregnancySymptomsScreen] offers these alongside the user's own
/// catalogue; tapping one that isn't in the catalogue yet adds it as an ordinary
/// custom symptom ([SymptomRepository.addType]) and logs it through the same
/// per-day symptom repo everything else uses.
///
/// Deliberately plain, non-clinical and gender-neutral — how you might feel, not
/// a medical checklist. Presence-only, like every other symptom in olf. The user
/// can rename, reorder or archive any of these once they are in the catalogue.
/// A name that matches an existing built-in (e.g. "Chest tenderness") reuses
/// that row rather than duplicating it.
const List<String> kPregnancySymptomNames = <String>[
  'Nausea',
  'Vomiting',
  'Fatigue',
  'Food cravings',
  'Food aversions',
  'Heartburn',
  'Swelling',
  'Back pain',
  'Chest tenderness',
  'Trouble sleeping',
  'Constipation',
  'Frequent urination',
  'Dizziness',
  'Braxton Hicks tightening',
  'Baby movements',
];

/// One-line intro above the pregnancy symptom chips.
const String pregnancySymptomsIntro =
    'Tap anything you notice today. These log the same way as your other '
    'symptoms — nothing here is a medical checklist, and every pregnancy is '
    'different.';

/// Heading over the user's own (non-curated) catalogue symptoms.
const String pregnancySymptomsOwnHeading = 'Your other symptoms';

/// Pregnancy-mode symptom logging (p7.2b).
///
/// Logs for **today** through the existing [SymptomRepository] — no new table,
/// no mode-specific storage. Reachable from [PregnancyWeekScreen] while
/// pregnancy mode is on.
class PregnancySymptomsScreen extends ConsumerStatefulWidget {
  const PregnancySymptomsScreen({super.key});

  @override
  ConsumerState<PregnancySymptomsScreen> createState() =>
      _PregnancySymptomsScreenState();
}

class _PregnancySymptomsScreenState
    extends ConsumerState<PregnancySymptomsScreen> {
  final DateTime _today = dateOnly(DateTime.now());
  final Set<int> _present = {};

  /// Curated names whose `addType` is in flight — guards against a double-tap
  /// creating two rows before the catalogue stream re-emits.
  final Set<String> _creating = {};

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final present = await ref
        .read(symptomRepositoryProvider)
        .symptomsOn(_today);
    if (!mounted) return;
    setState(() {
      _present
        ..clear()
        ..addAll(present);
      _loaded = true;
    });
  }

  void _toggle(int typeId, bool present) {
    setState(() {
      if (present) {
        _present.add(typeId);
      } else {
        _present.remove(typeId);
      }
    });
    ref
        .read(symptomRepositoryProvider)
        .setSymptom(_today, typeId, present: present);
  }

  Future<void> _addCurated(String name) async {
    if (!_creating.add(name)) return; // already being created
    try {
      final type = await ref.read(symptomRepositoryProvider).addType(name);
      if (!mounted) return;
      setState(() => _present.add(type.id));
      await ref
          .read(symptomRepositoryProvider)
          .setSymptom(_today, type.id, present: true);
    } on SymptomTypeException {
      // Name became unusable between the tap and the write (e.g. added
      // elsewhere) — the catalogue stream will surface it as a normal chip.
    } finally {
      _creating.remove(name);
    }
  }

  void _openManage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ManageSymptomsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types =
        ref.watch(symptomTypesProvider).value ?? const <SymptomType>[];
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    final byLowerName = <String, SymptomType>{
      for (final t in types) t.name.toLowerCase(): t,
    };
    final curatedLower = {
      for (final n in kPregnancySymptomNames) n.toLowerCase(),
    };
    final ownTypes = [
      for (final t in types)
        if (!curatedLower.contains(t.name.toLowerCase())) t,
    ];

    Widget chip({
      required String label,
      required bool selected,
      required ValueChanged<bool> onSelected,
    }) => FilterChip(
      label: Text(
        label,
        semanticsLabel: spokenLabel(reduceSpoken, redacted: 'symptom'),
      ),
      selected: selected,
      onSelected: onSelected,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pregnancy symptoms')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Today — ${formatDay(_today)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            pregnancySymptomsIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in kPregnancySymptomNames)
                if (byLowerName[name.toLowerCase()] case final existing?)
                  chip(
                    label: existing.name,
                    selected: _present.contains(existing.id),
                    onSelected: (v) => _toggle(existing.id, v),
                  )
                else
                  chip(
                    label: name,
                    selected: false,
                    onSelected: (_) => _addCurated(name),
                  ),
            ],
          ),
          if (ownTypes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              pregnancySymptomsOwnHeading,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in ownTypes)
                  chip(
                    label: t.name,
                    selected: _present.contains(t.id),
                    onSelected: (v) => _toggle(t.id, v),
                  ),
              ],
            ),
          ] else if (_loaded && types.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Your symptom list is empty — the taps above will start it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openManage,
              icon: const Icon(Icons.tune),
              label: const Text('Manage symptoms'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
          const SizedBox(height: 16),
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
}
