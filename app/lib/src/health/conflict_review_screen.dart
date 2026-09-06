import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../bbt/bbt_format.dart';
import '../bbt/bbt_providers.dart';
import '../flow/flow_format.dart';
import '../period/period_format.dart';
import 'health_providers.dart';

/// Resolve the differences the last sync could not apply automatically (p6.4).
///
/// A plain list: for each conflict the user sees their own entry next to the
/// incoming one and picks *keep mine* (write the app value back out), *use
/// theirs* (store the incoming value as a manual entry), or *dismiss* (leave
/// both, it reappears next sync). No bulk actions by design.
class ConflictReviewScreen extends ConsumerWidget {
  const ConflictReviewScreen({super.key});

  static const String title = 'Review differences';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(healthConflictsProvider);
    final platformName = ref.watch(healthPlatformNameProvider);
    final unit =
        ref.watch(temperatureUnitProvider).valueOrNull ??
        TemperatureUnit.celsius;

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: conflicts.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: conflicts.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'olf and $platformName have different entries for these '
                      'days. Your entries are never changed until you choose.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                final conflict = conflicts[i - 1];
                return _ConflictCard(
                  conflict: conflict,
                  platformName: platformName,
                  unit: unit,
                  onResolve: (how) => _resolve(context, ref, conflict, how),
                );
              },
            ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    ReconciliationConflict conflict,
    ConflictResolution how,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await resolveHealthConflict(ref, conflict, how);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That value couldn't be saved.")),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (how) {
          ConflictResolution.keepLocal => 'Kept your entry.',
          ConflictResolution.takeIncoming => 'Used the imported entry.',
          ConflictResolution.dismiss => 'Left for now.',
        }),
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.platformName,
    required this.unit,
    required this.onResolve,
  });

  final ReconciliationConflict conflict;
  final String platformName;
  final TemperatureUnit unit;
  final void Function(ConflictResolution how) onResolve;

  String _describe(HealthSampleType type, double value) => switch (type) {
    HealthSampleType.basalBodyTemperature => formatTemp(value, unit),
    HealthSampleType.menstrualFlow =>
      FlowIntensity
          .values[value.round().clamp(0, FlowIntensity.values.length - 1)]
          .label,
    HealthSampleType.bodyTemperature ||
    HealthSampleType.wristTemperature ||
    HealthSampleType.sleep => value.toString(),
  };

  String get _typeLabel => switch (conflict.local.type) {
    HealthSampleType.basalBodyTemperature => 'Basal body temperature',
    HealthSampleType.menstrualFlow => 'Menstrual flow',
    HealthSampleType.bodyTemperature => 'Body temperature',
    HealthSampleType.wristTemperature => 'Wrist temperature',
    HealthSampleType.sleep => 'Sleep',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = _describe(conflict.local.type, conflict.local.value);
    final theirs = _describe(conflict.incoming.type, conflict.incoming.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                '$_typeLabel — ${formatDay(conflict.local.day)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            _ValueRow(label: 'Your entry', value: mine),
            const SizedBox(height: 4),
            _ValueRow(label: platformName, value: theirs),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => onResolve(ConflictResolution.keepLocal),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Keep mine'),
                ),
                TextButton(
                  onPressed: () => onResolve(ConflictResolution.takeIncoming),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text('Use $platformName'),
                ),
                TextButton(
                  onPressed: () => onResolve(ConflictResolution.dismiss),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nothing to review.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
