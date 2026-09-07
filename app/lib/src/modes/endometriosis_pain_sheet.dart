import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'endometriosis_format.dart';
import 'endometriosis_mode_providers.dart';

/// Log (or edit) today's endometriosis pain / flare entry (p7.5) as a full page
/// — the button on [EndometriosisScreen] pushes this. The body is
/// [EndometriosisPainBody]; this is only the [Scaffold] / [AppBar] wrapper.
class EndometriosisPainSheet extends StatelessWidget {
  const EndometriosisPainSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log pain')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          EndometriosisPainBody(onDone: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// The pain / flare log form itself, with no page chrome, so it can be shown as
/// a full page ([EndometriosisPainSheet]) or as a section inside the unified
/// day-log sheet (r2).
///
/// Writes one row per day through [PainRepository]; the ordered intensity is
/// required, the region and note are optional, and "flare" is a plain toggle.
/// Removing the entry deletes the row (a day with no pain is the absence of a
/// row). [onDone] is called after a save / remove (the full page pops; the
/// day-log section keeps the sheet open).
class EndometriosisPainBody extends ConsumerStatefulWidget {
  const EndometriosisPainBody({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  ConsumerState<EndometriosisPainBody> createState() =>
      _EndometriosisPainBodyState();
}

class _EndometriosisPainBodyState extends ConsumerState<EndometriosisPainBody> {
  final DateTime _today = dateOnly(DateTime.now());
  final TextEditingController _note = TextEditingController();

  SymptomSeverity? _intensity;
  PainRegion? _region;
  bool _isFlare = false;
  bool _prefilled = false;
  bool _hadEntry = false;

  /// The three intensities the log offers — `none` is "no entry", handled by
  /// removing the row.
  static const List<SymptomSeverity> _scale = [
    SymptomSeverity.mild,
    SymptomSeverity.moderate,
    SymptomSeverity.severe,
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Prefill once, the first time the pain log has actually loaded — so an
  /// existing entry for today opens populated and "Save" edits it in place.
  void _prefillFrom(List<PainEntry> entries) {
    if (_prefilled) return;
    _prefilled = true;
    final entry = entries.where((e) => e.date == _today).firstOrNull;
    if (entry == null) return;
    _hadEntry = true;
    _intensity = entry.intensity;
    _region = entry.region;
    _isFlare = entry.isFlare;
    _note.text = entry.note ?? '';
  }

  Future<void> _save() async {
    final intensity = _intensity;
    if (intensity == null) return;
    await ref
        .read(painRepositoryProvider)
        .setPain(
          _today,
          intensity: intensity,
          region: _region,
          note: _note.text,
          isFlare: _isFlare,
        );
    if (mounted) widget.onDone?.call();
  }

  Future<void> _remove() async {
    await ref.read(painRepositoryProvider).clearDay(_today);
    if (mounted) widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(painEntriesProvider).whenData(_prefillFrom);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Today — ${formatDay(_today)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 20),

        Text('How bad is it?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in _scale)
              ChoiceChip(
                label: Text(s.label),
                selected: _intensity == s,
                onSelected: (_) => setState(() => _intensity = s),
              ),
          ],
        ),

        const SizedBox(height: 20),
        Text('Where? (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final r in PainRegion.values)
              ChoiceChip(
                label: Text(painRegionLabel(r)),
                selected: _region == r,
                onSelected: (sel) => setState(() => _region = sel ? r : null),
              ),
          ],
        ),

        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('This is a flare'),
          subtitle: const Text('A distinct bad episode, not background pain'),
          value: _isFlare,
          onChanged: (v) => setState(() => _isFlare = v),
        ),

        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: kPainNoteMaxLength,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            border: OutlineInputBorder(),
            helperText: 'Stays on this device. Never shown in a notification.',
          ),
        ),

        const SizedBox(height: 16),
        FilledButton(
          onPressed: _intensity == null ? null : _save,
          child: const Text('Save'),
        ),
        if (_hadEntry) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _remove,
            child: const Text("Remove today's entry"),
          ),
        ],
      ],
    );
  }
}
