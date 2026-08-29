import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'symptom_providers.dart';

/// Add, rename, reorder and remove the symptoms that appear in the day sheet.
///
/// Removal is a soft archive (`SymptomRepository.archiveType`): the symptom
/// leaves the pickers but the days it was already logged on keep their meaning.
class ManageSymptomsPage extends ConsumerWidget {
  const ManageSymptomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(symptomTypesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage symptoms')),
      body: switch (typesAsync) {
        AsyncData(:final value) => _List(types: value),
        AsyncError() => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not read your symptoms.'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _promptAdd(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add symptom'),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.types});

  final List<SymptomType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (types.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your symptom list is empty. Add one to start logging.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: types.length,
      onReorder: (oldIndex, newIndex) {
        final ids = [for (final t in types) t.id];
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        ref.read(symptomRepositoryProvider).reorderTypes(ids);
      },
      itemBuilder: (context, index) {
        final type = types[index];
        return ListTile(
          key: ValueKey(type.id),
          title: Text(type.name),
          subtitle: type.isBuiltIn ? const Text('Built-in') : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _promptRename(context, ref, type),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Rename',
              ),
              IconButton(
                onPressed: () => _confirmRemove(context, ref, type),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _promptAdd(BuildContext context, WidgetRef ref) async {
  final name = await _nameDialog(
    context,
    ref,
    title: 'Add symptom',
    initial: '',
  );
  if (name == null) return;
  await ref.read(symptomRepositoryProvider).addType(name);
}

Future<void> _promptRename(
  BuildContext context,
  WidgetRef ref,
  SymptomType type,
) async {
  final name = await _nameDialog(
    context,
    ref,
    title: 'Rename symptom',
    initial: type.name,
    editingCurrentName: type.name,
  );
  if (name == null) return;
  await ref.read(symptomRepositoryProvider).renameType(type.id, name);
}

Future<void> _confirmRemove(
  BuildContext context,
  WidgetRef ref,
  SymptomType type,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Remove ${type.name}?'),
      content: const Text(
        'It will stop appearing when you log a day. Days you already logged it '
        'on are kept.',
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
  await ref.read(symptomRepositoryProvider).archiveType(type.id);
  messenger.showSnackBar(SnackBar(content: Text('${type.name} removed.')));
}

/// A single-field dialog that validates the name as the user types and only
/// returns it (trimmed, via the caller) once it is acceptable.
Future<String?> _nameDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String initial,
  String? editingCurrentName,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final active = ref.read(symptomTypesProvider).value ?? const [];
          final error = controller.text.trim().isEmpty
              ? null // don't shout before they've typed
              : validateSymptomName(
                  controller.text,
                  existingActiveNames: active.map((t) => t.name),
                  editingCurrentName: editingCurrentName,
                )?.describe();
          final canSave =
              controller.text.trim().isNotEmpty &&
              validateSymptomName(
                    controller.text,
                    existingActiveNames: active.map((t) => t.name),
                    editingCurrentName: editingCurrentName,
                  ) ==
                  null;
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Symptom name',
                errorText: error,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (canSave) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: canSave
                    ? () => Navigator.of(
                        dialogContext,
                      ).pop(controller.text.trim())
                    : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
