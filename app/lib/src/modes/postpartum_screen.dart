import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/spoken_detail.dart';
import 'modes_providers.dart';
import 'postpartum_format.dart';
import 'support_resources_screen.dart';

/// The postpartum cycle-return view (p7.1): time since a recorded loss / birth,
/// whether a first period has been logged, and — once there are enough
/// post-event cycles — an honest "settling / still variable" read. No
/// fabricated next-period estimate; the prediction stays anchored on logged
/// periods and is simply "still settling" here.
class PostpartumScreen extends ConsumerWidget {
  const PostpartumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(postpartumCycleReturnProvider);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Postpartum')),
      body: r == null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Record a pregnancy loss or birth in Settings → '
                '"Pregnancy loss & birth" and this view will track your '
                'cycle coming back.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  postpartumHeadline(r),
                  style: theme.textTheme.titleMedium,
                  semanticsLabel: spokenLabel(
                    reduceSpoken,
                    redacted: postpartumHeadlineRedacted(r),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  postpartumStatusBody(r),
                  style: theme.textTheme.bodyMedium,
                  semanticsLabel: spokenLabel(
                    reduceSpoken,
                    redacted: postpartumStatusBodyRedacted(r),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    postpartumPredictorNote,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SupportResourcesScreen(kind: r.eventKind),
                    ),
                  ),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Support & resources'),
                ),
                const SizedBox(height: 24),
                Text(
                  postpartumDisclaimer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
