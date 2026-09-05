import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../bbt/bbt_format.dart';
import '../bbt/bbt_providers.dart';
import '../flow/flow_format.dart';
import '../period/period_format.dart';
import 'health_providers.dart';

/// Works through the conflicts from the last sync (p6.4) — one row per
/// disagreement, three actions each: **keep mine** (push the local value to the
/// platform), **use theirs** (write the incoming value as a manual entry), or
/// **later** (leave it; it re-surfaces next sync). No bulk actions.
///
/// The list is in-memory ([healthConflictsProvider]); resolving a row removes it
/// and, when the list empties, the screen shows a done state.
class ConflictReviewPage extends ConsumerWidget {
  const ConflictReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(healthConflictsProvider);
    final platformName = ref.watch(healthPlatformNameProvider);
    final unit =
        ref.watch(temperatureUnitProvider).valueOrNull ??
        TemperatureUnit.celsius;
    final reduceSpokenDetail =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Review sync conflicts')),
      body: conflicts.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conflicts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _ConflictTile(
                conflict: conflicts[i],
                platformName: platformName,
                unit: unit,
                reduceSpokenDetail: reduceSpokenDetail,
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Nothing to review',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Every difference between olf and your health app has been '
              'resolved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictTile extends ConsumerWidget {
  const _ConflictTile({
    required this.conflict,
    required this.platformName,
    required this.unit,
    required this.reduceSpokenDetail,
  });

  final ReconciliationConflict conflict;
  final String platformName;
  final TemperatureUnit unit;
  final bool reduceSpokenDetail;

  String get _typeLabel => switch (conflict.local.type) {
    HealthSampleType.menstrualFlow => 'Flow',
    HealthSampleType.basalBodyTemperature => 'Basal temperature',
    _ => 'Entry',
  };

  String _value(HealthSampleType type, double raw) => switch (type) {
    HealthSampleType.menstrualFlow =>
      FlowIntensity
          .values[raw.round().clamp(0, FlowIntensity.values.length - 1)]
          .label,
    HealthSampleType.basalBodyTemperature => formatTemp(raw, unit),
    _ => raw.toString(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = _value(conflict.local.type, conflict.local.value);
    final theirs = _value(conflict.incoming.type, conflict.incoming.value);
    final day = formatDay(conflict.local.day);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Semantics(
        container: true,
        label: spokenDetail(
          reduceSpokenDetail,
          full:
              '$_typeLabel on $day. Your value $mine, $platformName value '
              '$theirs.',
          redacted: '$_typeLabel entry on $day needs review.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_typeLabel · $day', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            _row(context, 'Your value', mine),
            _row(context, '$platformName value', theirs),
            const SizedBox(height: 4),
            OverflowBar(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => resolveConflictKeepLocal(ref, conflict),
                  child: const Text('Keep mine'),
                ),
                TextButton(
                  onPressed: () => resolveConflictTakeIncoming(ref, conflict),
                  child: const Text('Use theirs'),
                ),
                TextButton(
                  onPressed: () => dismissConflict(ref, conflict),
                  child: const Text('Later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
