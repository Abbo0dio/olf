import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../prediction/prediction_providers.dart';
import 'reminder_controller.dart';
import 'reminder_copy.dart';
import 'reminder_providers.dart';

/// Settings → Notifications (p4.1).
///
/// One independently-toggleable category per row. Each row reads and writes only
/// its own stored reminder — turning one on or off never touches another.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'All reminders are local to this device. The text is always '
              'generic — it never names a medication, method, or health detail.',
            ),
          ),
          for (final kind in reminderCategoryOrder) _CategoryTile(kind: kind),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.kind});

  final ReminderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reminderScheduleProvider(kind));
    final schedule = async.value;
    final enabled = schedule?.enabled ?? false;
    final hour = schedule?.hour ?? ReminderController.defaultHour;
    final minute = schedule?.minute ?? ReminderController.defaultMinute;
    final controller = ref.read(reminderControllerProvider);

    // Forecast-anchored kinds can be turned on any time, but there is nothing to
    // schedule until there is a prediction — show that honestly rather than a
    // time that would never fire.
    final needsForecast = isEventRelativeReminder(kind);
    final hasForecast = ref.watch(predictionProvider) != null;
    final awaitingHistory = needsForecast && !hasForecast;

    return Column(
      children: [
        SwitchListTile(
          value: enabled,
          title: Text(reminderCategoryTitle(kind)),
          subtitle: Text(reminderCategorySubtitle(kind)),
          onChanged: async.isLoading
              ? null
              : (value) => controller.setEnabled(kind, enabled: value),
        ),
        if (enabled && awaitingHistory)
          const Padding(
            padding: EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Available once there's enough logged history to predict.",
              ),
            ),
          )
        else if (enabled)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Time'),
            subtitle: Text(
              TimeOfDay(hour: hour, minute: minute).format(context),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
              );
              if (picked != null) {
                await controller.setTime(
                  kind,
                  hour: picked.hour,
                  minute: picked.minute,
                );
              }
            },
          ),
      ],
    );
  }
}
