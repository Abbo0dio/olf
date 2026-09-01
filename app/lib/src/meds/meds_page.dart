import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'meds_providers.dart';

/// Record medications and a birth-control method (p1.7).
///
/// Everything here is optional and local. The daily "remind me to take it"
/// notification is no longer set here — it is the `medication` category in
/// Settings → Notifications, on the same unified path as every other reminder
/// (p4.6). The stored reminder row is untouched by that move.
class MedsPage extends ConsumerWidget {
  const MedsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const [
          _SectionHeader('Birth control'),
          _BirthControlSection(),
          Divider(height: 32),
          _SectionHeader('Medications'),
          _MedicationsSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Birth control
// ---------------------------------------------------------------------------

class _BirthControlSection extends ConsumerWidget {
  const _BirthControlSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentBirthControlProvider).value;
    final repo = ref.read(birthControlRepositoryProvider);

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.medical_services_outlined),
          title: Text(current == null ? 'None set' : current.method.label),
          subtitle: current == null
              ? const Text('Add the method you use, if any.')
              : Text('Since ${formatDay(current.startedOn)}'),
          trailing: TextButton(
            onPressed: () => _pickMethod(context, ref, current?.method),
            child: Text(current == null ? 'Set' : 'Change'),
          ),
        ),
        if (current != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextButton(
                onPressed: () => repo.stop(),
                child: const Text('Stop using'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMethod(
    BuildContext context,
    WidgetRef ref,
    BirthControlMethod? currentMethod,
  ) async {
    final picked = await showModalBottomSheet<BirthControlMethod>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Birth-control method'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final method in BirthControlMethod.values)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: method == currentMethod,
                    onSelected: (_) => Navigator.of(sheetContext).pop(method),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
    if (picked == null || picked == currentMethod) return;
    await ref.read(birthControlRepositoryProvider).switchTo(picked);
  }
}

// ---------------------------------------------------------------------------
// Medications
// ---------------------------------------------------------------------------

class _MedicationsSection extends ConsumerWidget {
  const _MedicationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider).value ?? const <Medication>[];

    return Column(
      children: [
        if (meds.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('No medications added.'),
            ),
          ),
        for (final med in meds)
          ListTile(
            title: Text(med.name),
            subtitle: med.dosage == null ? null : Text(med.dosage!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editDialog(context, ref, med),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      ref.read(medicationRepositoryProvider).archive(med.id),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              onPressed: () => _editDialog(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editDialog(
    BuildContext context,
    WidgetRef ref,
    Medication? existing,
  ) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final dosageController = TextEditingController(
      text: existing?.dosage ?? '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final error = nameController.text.trim().isEmpty
              ? null
              : validateMedicationName(nameController.text)?.describe();
          final canSave =
              nameController.text.trim().isNotEmpty &&
              validateMedicationName(nameController.text) == null;
          return AlertDialog(
            title: Text(
              existing == null ? 'Add medication' : 'Edit medication',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: error,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (optional)',
                  ),
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: canSave
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    final repo = ref.read(medicationRepositoryProvider);
    final name = nameController.text;
    final dosage = dosageController.text;
    final notes = notesController.text;
    if (existing == null) {
      await repo.add(name, dosage: dosage, notes: notes);
    } else {
      await repo.edit(existing.id, name: name, dosage: dosage, notes: notes);
    }
  }
}
