import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../backup/backup_page.dart';
import '../export/export_report_screen.dart';
import '../health/conflict_review_screen.dart';
import '../health/health_import.dart';
import '../health/health_providers.dart';
import '../period/period_format.dart';

/// "Data & sharing" (r4): the rows that move data in or out of olf — backups,
/// the doctor report, and the health-platform bridge — split out of
/// `settings_page.dart` so Settings holds only settings.
///
/// Everything here was lifted verbatim from the old Settings "Data" /
/// "Apps & export" sections; the only change is the host screen. The health
/// sync summary keeps its `reduceSpokenDetail` redaction.
class DataAndSharingScreen extends ConsumerWidget {
  const DataAndSharingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceSpokenDetail =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
    final healthAvailable =
        ref.watch(healthAvailableProvider).valueOrNull ?? false;
    final healthName = ref.watch(healthPlatformNameProvider);
    final healthConnected =
        ref.watch(healthConnectedProvider).valueOrNull ?? false;
    final healthLastSync = ref.watch(healthLastSyncProvider).valueOrNull;
    final healthReviewCount = ref.watch(healthConflictsProvider).length;
    // p8.1a: how many passive Apple Watch wrist-temperature readings olf holds.
    final passiveWristCount = ref.watch(passiveWristTempCountProvider);
    // p8.2: the devices / apps behind the imported readings olf holds (Oura,
    // Garmin, …). Empty for an all-manual database.
    final contributingDevices = ref.watch(contributingDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Data & sharing')),
      body: ListView(
        children: [
          const _SectionHeader('On this device'),
          ListTile(
            leading: const Icon(Icons.save_outlined),
            title: const Text('Backup & restore'),
            subtitle: const Text(
              'Save an encrypted copy of everything, or restore one.',
            ),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BackupPage())),
          ),
          const _SectionHeader('Sharing'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Export report for a doctor'),
            subtitle: const Text(
              'A print-friendly PDF of your cycles, symptoms and temperature to '
              'share with a clinician. Made on your device.',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ExportReportScreen(),
              ),
            ),
          ),
          if (healthAvailable) ...[
            SwitchListTile(
              secondary: const Icon(Icons.sync_outlined),
              value: healthConnected,
              title: const Text('Connect a health app'),
              subtitle: _healthSubtitle(
                name: healthName,
                connected: healthConnected,
                lastSync: healthLastSync,
                reduceSpokenDetail: reduceSpokenDetail,
              ),
              onChanged: (want) => want
                  ? _connectHealth(context, ref)
                  : _disconnectHealth(context, ref),
            ),
            if (healthConnected)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Sync now'),
                onTap: () => _syncHealth(context, ref),
              ),
            // p8.1a: per-source line for the passive Apple Watch path — only
            // shown once real wrist readings have been imported.
            if (healthConnected && passiveWristCount > 0)
              ListTile(
                leading: const Icon(Icons.watch_outlined),
                title: const Text('Apple Watch wrist temperature'),
                subtitle: Text(
                  '$passiveWristCount passive '
                  '${passiveWristCount == 1 ? 'reading' : 'readings'} '
                  'captured while you slept. Not used for fertility signals.',
                  semanticsLabel: spokenLabel(
                    reduceSpokenDetail,
                    redacted:
                        'Passive Apple Watch readings are being imported.',
                  ),
                ),
              ),
            // p8.2: per-device provenance for third-party wearables (Oura,
            // Garmin, …) whose data reaches olf through the health platform.
            // Only shown once at least one imported reading carries a device
            // tag; no per-device controls — disconnecting the platform keeps
            // the readings.
            if (healthConnected && contributingDevices.isNotEmpty) ...[
              for (final device in contributingDevices)
                ListTile(
                  leading: const Icon(Icons.devices_outlined),
                  title: Text('From ${device.label}'),
                  subtitle: Text(
                    '${device.readingCount} '
                    '${device.readingCount == 1 ? 'reading' : 'readings'} '
                    '· last ${formatDay(device.lastDay)}',
                    semanticsLabel: spokenLabel(
                      reduceSpokenDetail,
                      redacted: 'A connected device is contributing readings.',
                    ),
                  ),
                ),
            ],
            if (healthConnected && healthReviewCount > 0)
              ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: Text(
                  '$healthReviewCount '
                  '${healthReviewCount == 1 ? 'difference' : 'differences'} '
                  'to review',
                ),
                subtitle: Text(
                  'olf and $healthName disagree on some days. Choose which '
                  'entry to keep.',
                  semanticsLabel: spokenLabel(
                    reduceSpokenDetail,
                    redacted: 'Some entries need your review.',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConflictReviewScreen(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Subtitle for the "Connect a health app" tile. When connected and a sync
  /// has run it names the counts and when it ran; under "Reduce spoken detail"
  /// the screen reader hears only that the bridge is on.
  Widget _healthSubtitle({
    required String name,
    required bool connected,
    required HealthSyncSummary? lastSync,
    required bool reduceSpokenDetail,
  }) {
    if (!connected) {
      return Text("Off. olf isn't reading or writing $name.");
    }
    final String visible;
    if (lastSync == null) {
      visible =
          'On. Sharing menstrual flow and basal body temperature with $name.';
    } else {
      final when = lastSync.at == null ? '' : ' · ${_ago(lastSync.at!)}';
      visible =
          'On. Last sync: added ${lastSync.added}, updated '
          '${lastSync.updated}$when.';
    }
    return Text(
      visible,
      semanticsLabel: spokenLabel(
        reduceSpokenDetail,
        redacted: '$name is connected.',
      ),
    );
  }

  /// A short "when" for the last sync — "just now", "5 min ago", "3 h ago", or
  /// the date once it is more than a day old.
  static String _ago(DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    return formatDay(at);
  }

  Future<void> _connectHealth(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(healthPlatformNameProvider);
    final revokeHint = ref.read(healthRevokeHintProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Connect $name'),
        content: SingleChildScrollView(
          child: Text(
            'olf and $name will share two things: menstrual flow and '
            'basal body temperature.\n\n'
            'In — entries already in $name appear in olf.\n'
            'Out — what you log in olf is saved to $name.\n\n'
            'Nothing else is shared and nothing leaves your device. You can '
            'turn this off here at any time; to fully revoke access, use '
            '$revokeHint.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final summary = await connectHealthPlatform(ref);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('$name connected'),
          content: Text(_summarySentence(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on HealthAuthorizationDenied {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name access was not granted. Nothing changed.'),
        ),
      );
    } on HealthPlatformUnavailable {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't reach $name. Nothing changed.")),
      );
    }
  }

  Future<void> _syncHealth(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(healthPlatformNameProvider);
    try {
      final summary = await syncHealthPlatform(ref);
      messenger.showSnackBar(
        SnackBar(content: Text(_summarySentence(summary))),
      );
    } on HealthPlatformUnavailable {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't reach $name. Nothing changed.")),
      );
    }
  }

  Future<void> _disconnectHealth(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = ref.read(healthPlatformNameProvider);
    final revokeHint = ref.read(healthRevokeHintProvider);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Disconnect $name?'),
        content: Text(
          'olf will stop reading and writing $name data. Entries already '
          'saved on each side stay where they are. To fully revoke '
          "olf's access, use $revokeHint.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await disconnectHealthPlatform(ref);
    messenger.showSnackBar(SnackBar(content: Text('$name disconnected.')));
  }

  String _summarySentence(HealthSyncSummary summary) {
    if (summary.nothingChanged) return 'No new entries to bring in.';
    final review = summary.needsReview > 0
        ? ', ${summary.needsReview} need review.'
        : '.';
    return 'Added ${summary.added}, updated ${summary.updated}$review';
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
