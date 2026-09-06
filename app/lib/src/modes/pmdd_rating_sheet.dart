import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_format.dart';
import 'pmdd_format.dart';
import 'pmdd_mode_providers.dart';

/// Rate (or edit) today's PMDD entry (p7.6).
///
/// A short fixed list of items ([PmddSymptom.values]), each on the shared
/// [SymptomSeverity] scale with `None` selected by default. "Save" writes one
/// row per item through [PmddRatingRepository] — a `None` rating is stored, so
/// the day counts as rated. "Clear today's rating" deletes every row for today.
class PmddRatingSheet extends ConsumerStatefulWidget {
  const PmddRatingSheet({super.key});

  @override
  ConsumerState<PmddRatingSheet> createState() => _PmddRatingSheetState();
}

class _PmddRatingSheetState extends ConsumerState<PmddRatingSheet> {
  final DateTime _today = dateOnly(DateTime.now());
  final Map<PmddSymptom, SymptomSeverity> _ratings = {
    for (final item in PmddSymptom.values) item: SymptomSeverity.none,
  };

  bool _prefilled = false;
  bool _hadEntry = false;

  /// Prefill once, the first time the ratings stream has actually loaded — so an
  /// existing entry for today opens populated and "Save" edits it in place.
  void _prefillFrom(List<PmddRating> rows) {
    if (_prefilled) return;
    _prefilled = true;
    final todays = {
      for (final r in rows)
        if (dateOnly(r.date) == _today) r.item: r.rating,
    };
    if (todays.isEmpty) return;
    _hadEntry = true;
    for (final entry in todays.entries) {
      _ratings[entry.key] = entry.value;
    }
  }

  Future<void> _save() async {
    await ref.read(pmddRatingRepositoryProvider).rateDay(_today, _ratings);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(pmddRatingRepositoryProvider).clearDay(_today);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(pmddRatingsProvider).whenData(_prefillFrom);

    return Scaffold(
      appBar: AppBar(title: const Text(pmddSheetTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Today — ${formatDay(_today)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(pmddSheetIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),

          for (final item in PmddSymptom.values) ...[
            Text(pmddSymptomLabel(item), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<SymptomSeverity>(
              showSelectedIcon: false,
              segments: [
                for (final s in SymptomSeverity.ordered)
                  ButtonSegment<SymptomSeverity>(
                    value: s,
                    label: Text(s.label),
                  ),
              ],
              selected: {_ratings[item]!},
              onSelectionChanged: (sel) =>
                  setState(() => _ratings[item] = sel.first),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 4),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (_hadEntry) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clear,
              child: const Text("Clear today's rating"),
            ),
          ],
        ],
      ),
    );
  }
}
