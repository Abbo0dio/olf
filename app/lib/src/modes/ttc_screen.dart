import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import 'ttc_format.dart';
import 'ttc_providers.dart';

/// TTC mode's screen (p7.3): today's fertility score and the next few days, the
/// predicted fertile window as a range, plain non-prescriptive guidance, and an
/// honest empty state when there isn't enough history. The score is explicitly
/// framed as a relative likelihood from the user's own patterns — never a
/// promise — and the screen carries the not-a-medical-device line and a
/// "not contraception guidance" note.
class TtcScreen extends ConsumerWidget {
  const TtcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final outlook = ref.watch(ttcFertilityOutlookProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Trying to conceive')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: outlook.isEmpty
            ? _emptyState(theme)
            : _outlookView(theme, outlook, reduceSpoken: reduceSpoken),
      ),
    );
  }

  List<Widget> _emptyState(ThemeData theme) => [
    Text('Not enough history yet', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(ttcEmptyStateBody, style: theme.textTheme.bodyMedium),
    const SizedBox(height: 24),
    _disclaimer(theme),
  ];

  List<Widget> _outlookView(
    ThemeData theme,
    List<DailyFertilityScore> outlook, {
    required bool reduceSpoken,
  }) {
    final today = outlook.first;
    final rest = outlook.skip(1).toList();

    return [
      Text(
        ttcScoreHeadline(today),
        style: theme.textTheme.headlineSmall,
        semanticsLabel: spokenLabel(
          reduceSpoken,
          redacted: ttcScoreRedactedLabel,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        ttcScoreFraming,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        ttcScoreRangeLine(today),
        style: theme.textTheme.bodyMedium,
        semanticsLabel: spokenLabel(
          reduceSpoken,
          redacted: ttcScoreRedactedLabel,
        ),
      ),
      Text(
        ttcConfidenceLabel(today.confidence),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        ttcFertileWindowLine(today.fertileWindow),
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(ttcGuidance(today), style: theme.textTheme.bodyMedium),
      ),
      const SizedBox(height: 20),
      Text("What shaped today's score", style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      for (final factor in today.factors)
        if (ttcFactorExplanation(factor) case final line?)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.textTheme.bodyMedium),
                Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      const SizedBox(height: 20),
      Text('Next days', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      for (var i = 0; i < rest.length; i++) _DayRow(day: rest[i], index: i + 1),
      const SizedBox(height: 24),
      _disclaimer(theme),
    ];
  }

  Widget _disclaimer(ThemeData theme) => Text(
    ttcModeDisclaimer,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.index});

  final DailyFertilityScore day;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = ttcDayLabel(day.date, index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label:
            '$label: fertility score ${day.score} out of 100'
            '${day.isPeak ? ', estimated peak' : ''}',
        child: ExcludeSemantics(
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: day.score / 100,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Text(
                  day.isPeak ? '${day.score} ★' : '${day.score}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
