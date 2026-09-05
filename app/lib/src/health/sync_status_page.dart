import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../period/period_format.dart';
import 'conflict_review_page.dart';
import 'health_import.dart';
import 'health_providers.dart';

/// Per-platform sync status (p6.4): connected state, when the last sync ran,
/// what it did, how many differences still need review, and a "Sync now"
/// action. Reached from Settings → Apps & export.
class HealthSyncStatusPage extends ConsumerWidget {
  const HealthSyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(healthPlatformNameProvider);
    final connected = ref.watch(healthConnectedProvider).valueOrNull ?? false;
    final lastSync = ref.watch(healthLastSyncProvider).valueOrNull;
    final lastSyncAt = ref.watch(healthLastSyncAtProvider).valueOrNull;
    final conflicts = ref.watch(healthConflictsProvider);
    final reduceSpokenDetail =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Health sync')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(name),
            subtitle: Text(connected ? 'Connected' : 'Not connected'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Last synced'),
            subtitle: Text(
              lastSyncAt == null
                  ? 'Not synced yet'
                  : _relativeTime(lastSyncAt, DateTime.now()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('Last sync brought in'),
            subtitle: Text(
              lastSync == null
                  ? 'Nothing yet'
                  : 'Added ${lastSync.added}, updated ${lastSync.updated}',
              semanticsLabel: spokenLabel(
                reduceSpokenDetail,
                redacted: lastSync == null
                    ? 'Nothing yet'
                    : 'Last sync complete',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('Needs review'),
            subtitle: Text(
              conflicts.isEmpty
                  ? 'No differences to resolve'
                  : '${conflicts.length} '
                        '${conflicts.length == 1 ? 'difference' : 'differences'} '
                        'between olf and $name',
              semanticsLabel: spokenLabel(
                reduceSpokenDetail,
                redacted: conflicts.isEmpty
                    ? 'Nothing to review'
                    : '${conflicts.length} entries need review',
              ),
            ),
            trailing: conflicts.isEmpty
                ? null
                : const Icon(Icons.chevron_right),
            enabled: conflicts.isNotEmpty,
            onTap: conflicts.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConflictReviewPage(),
                    ),
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: connected ? () => _syncNow(context, ref) : null,
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
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

  String _summarySentence(HealthSyncSummary summary) {
    if (summary.nothingChanged) return 'No new entries to bring in.';
    final review = summary.needsReview > 0
        ? ', ${summary.needsReview} need review.'
        : '.';
    return 'Added ${summary.added}, updated ${summary.updated}$review';
  }
}

/// A short "… ago" phrase, falling back to the date once it is more than a week
/// old. Kept local — the only place olf shows a relative timestamp.
String _relativeTime(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.isNegative || d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (d.inHours < 24) {
    final h = d.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (d.inDays < 7) {
    final days = d.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }
  return 'on ${formatDay(then)}';
}
