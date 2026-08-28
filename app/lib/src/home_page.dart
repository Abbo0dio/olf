import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'providers.dart';

/// Home screen. p0.4 scope: one real action — log that your period started
/// today — plus the "Day N" readout and an undo/remove path.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('olf')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (database) {
            AsyncData() => const _HomeBody(),
            AsyncError(:final error) => _DatabaseUnavailable(error: error),
            _ => const _Busy(message: 'Opening your private database'),
          },
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(label: message, child: const CircularProgressIndicator());
  }
}

/// Shown when the database can't be opened. For a missing key this is a
/// deliberate dead-end: the data is safe on the device but stays sealed.
class _DatabaseUnavailable extends StatelessWidget {
  const _DatabaseUnavailable({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missingKey = error is MissingDatabaseKeyException;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          missingKey ? "Can't unlock your data" : "Can't open the app",
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          missingKey
              ? 'Your entries are still encrypted and safe on this device, but '
                    'the key that opens them is missing. Nothing has been '
                    'changed or deleted.'
              : 'Something went wrong opening the local database. Nothing has '
                    'been changed or deleted.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(mostRecentPeriodStartProvider);
    return switch (latest) {
      AsyncData(:final value?) => _LoggedState(event: value),
      AsyncData() => const _EmptyState(),
      AsyncError() => const Text('Could not read your entries.'),
      _ => const _Busy(message: 'Loading your entries'),
    };
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nothing logged yet.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _logToday(context, ref),
          style: FilledButton.styleFrom(minimumSize: const Size(240, 52)),
          icon: const Icon(Icons.water_drop_outlined),
          label: const Text('Period started today'),
        ),
      ],
    );
  }

  Future<void> _logToday(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(cycleEventRepositoryProvider);
    final id = await repo.logPeriodStart(DateTime.now());
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Logged. This is day 1.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.deleteEvent(id),
        ),
      ),
    );
  }
}

class _LoggedState extends ConsumerWidget {
  const _LoggedState({required this.event});
  final CycleEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = dayCountSince(event.date, DateTime.now());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Day $day',
          style: theme.textTheme.displaySmall,
          semanticsLabel: 'Day $day of your period',
        ),
        const SizedBox(height: 8),
        Text('Period started ${_formatDate(event.date)}'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _remove(context, ref),
          style: OutlinedButton.styleFrom(minimumSize: const Size(240, 52)),
          icon: const Icon(Icons.undo),
          label: const Text('Remove this entry'),
        ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(cycleEventRepositoryProvider);
    final date = event.date;
    await repo.deleteEvent(event.id);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.logPeriodStart(date),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}
