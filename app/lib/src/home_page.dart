import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'meds/meds_page.dart';
import 'period/period_calendar_page.dart';
import 'providers.dart';
import 'retention/retention_providers.dart';
import 'settings/settings_page.dart';

/// Home screen. Gates on the encrypted database opening, then hands off to the
/// period calendar (p1.1). A missing key is a deliberate dead-end.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);
    // p2.3: run the scheduled auto-deletion sweep once we're in the app.
    // Fire-and-forget — a no-op unless a retention window is set on the real
    // vault. Kept here so it never runs behind the lock or first-run screens.
    ref.watch(retentionStartupSweepProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('olf'),
        actions: [
          if (database case AsyncData()) ...[
            IconButton(
              icon: const Icon(Icons.medication_outlined),
              tooltip: 'Medications & reminders',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const MedsPage())),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ],
      ),
      body: switch (database) {
        AsyncData() => const PeriodCalendarView(),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _DatabaseUnavailable(error: error),
          ),
        ),
        _ => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _Busy(message: 'Opening your private database'),
          ),
        ),
      },
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
