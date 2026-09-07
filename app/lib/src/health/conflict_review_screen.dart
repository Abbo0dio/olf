import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../bbt/bbt_format.dart';
import '../bbt/bbt_providers.dart';
import '../flow/flow_format.dart';
import '../period/period_format.dart';
import 'device_label.dart';
import 'health_providers.dart';

/// Resolve the differences the last sync could not apply automatically (p6.4,
/// extended for N sources in p8.6).
///
/// A plain list: for each conflict the user sees every source's value for that
/// day, a short line on which reading would win and why, and picks *keep mine*
/// (write the app value back out), *use <source>* (store that reading), or
/// *dismiss* (leave everything, it reappears next sync). No bulk actions by
/// design.
class ConflictReviewScreen extends ConsumerWidget {
  const ConflictReviewScreen({super.key});

  static const String title = 'Review differences';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(healthConflictsProvider);
    final platformName = ref.watch(healthPlatformNameProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
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
                  final anyMultiSource = conflicts.any(
                    (c) =>
                        c.reason == ConflictReason.crossDeviceDisagreement ||
                        c.alsoContending.isNotEmpty,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      anyMultiSource
                          ? 'Some days have different readings from more than '
                                'one source. Nothing is changed until you '
                                'choose which to keep.'
                          : 'olf and $platformName have different entries for '
                                'these days. Your entries are never changed '
                                'until you choose.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                final conflict = conflicts[i - 1];
                return _ConflictCard(
                  conflict: conflict,
                  platformName: platformName,
                  unit: unit,
                  reduceSpoken: reduceSpoken,
                  onKeepLocal: () => _resolve(
                    context,
                    ref,
                    () => resolveHealthConflict(
                      ref,
                      conflict,
                      ConflictResolution.keepLocal,
                    ),
                    'Kept your entry.',
                  ),
                  onDismiss: () => _resolve(
                    context,
                    ref,
                    () => resolveHealthConflict(
                      ref,
                      conflict,
                      ConflictResolution.dismiss,
                    ),
                    'Left for now.',
                  ),
                  onUseReading: (s) => _resolve(
                    context,
                    ref,
                    () => resolveHealthConflictWithReading(ref, conflict, s),
                    'Saved the reading you chose.',
                  ),
                );
              },
            ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("That value couldn't be saved.")),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  }
}

/// One row's worth of "a source and its value for this day".
class _SourceLine {
  const _SourceLine({required this.name, required this.value, this.reading});

  final String name;
  final String value;

  /// The reading to store if the user picks this line. `null` for the local /
  /// app-entered row, which "keep mine" handles instead.
  final HealthSample? reading;
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.platformName,
    required this.unit,
    required this.reduceSpoken,
    required this.onKeepLocal,
    required this.onDismiss,
    required this.onUseReading,
  });

  final ReconciliationConflict conflict;
  final String platformName;
  final TemperatureUnit unit;
  final bool reduceSpoken;
  final VoidCallback onKeepLocal;
  final VoidCallback onDismiss;
  final void Function(HealthSample reading) onUseReading;

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

  String _sourceName(HealthSample s, String fallback) =>
      prettyDeviceLabel(s.sourceDevice) ??
      (s.source == HealthDataSource.manual ? 'Your entry' : fallback);

  /// Every source for this day, local first.
  List<_SourceLine> _lines() {
    final crossDevice =
        conflict.reason == ConflictReason.crossDeviceDisagreement;
    final localName = crossDevice
        ? (prettyDeviceLabel(conflict.local.sourceDevice) ?? 'One device')
        : 'Your entry';

    return [
      _SourceLine(
        name: localName,
        value: _describe(conflict.local.type, conflict.local.value),
      ),
      _SourceLine(
        name: crossDevice
            ? _sourceName(conflict.incoming, 'Another device')
            : platformName,
        value: _describe(conflict.incoming.type, conflict.incoming.value),
        reading: conflict.incoming,
      ),
      for (final s in conflict.alsoContending)
        _SourceLine(
          name: _sourceName(s, 'Another device'),
          value: _describe(s.type, s.value),
          reading: s,
        ),
    ];
  }

  String get _whyLine => switch (conflict.reason) {
    ConflictReason.manualDisagreement =>
      'Your typed entry stays unless you pick another.',
    ConflictReason.crossSourceDisagreement =>
      'These came from different apps. Nothing changes until you choose.',
    ConflictReason.crossDeviceDisagreement =>
      'These are the same kind of source — choose which to keep.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _lines();
    final crossDevice =
        conflict.reason == ConflictReason.crossDeviceDisagreement;
    // p6.4 kept "Keep mine" for a your-entry-vs-platform conflict; p8.2 named
    // the button by device when neither side is the user's own entry.
    final keepButtonText = crossDevice
        ? 'Keep ${lines.first.name}'
        : 'Keep mine';

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
            const SizedBox(height: 4),
            Text(
              _whyLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              _ValueRow(
                label: line.name,
                value: line.value,
                reduceSpoken: reduceSpoken,
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: onKeepLocal,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(keepButtonText),
                ),
                for (final line in lines.where((l) => l.reading != null))
                  TextButton(
                    onPressed: () => onUseReading(line.reading!),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: Text('Use ${line.name}'),
                  ),
                TextButton(
                  onPressed: onDismiss,
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
  const _ValueRow({
    required this.label,
    required this.value,
    required this.reduceSpoken,
  });

  final String label;
  final String value;
  final bool reduceSpoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: spokenDetail(
        reduceSpoken,
        full: '$label: $value',
        redacted: '$label: entry hidden',
      ),
      excludeSemantics: true,
      child: Row(
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
        child: Text(
          'Nothing to review.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
