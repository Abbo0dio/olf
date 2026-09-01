import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../prediction/prediction_providers.dart';
import 'quiet_hours_providers.dart';
import 'reminder_controller.dart';
import 'reminder_copy.dart';
import 'reminder_providers.dart';

/// Settings → Notifications (p4.1, p4.2).
///
/// One independently-toggleable category per row. Each row reads and writes only
/// its own stored reminder — turning one on or off never touches another.
///
/// For the forecast-anchored kinds the time control is honest about p4.2: once
/// there is a learned logging hour it drives delivery, so the row shows that
/// effective time read-only instead of a picker that would be silently ignored.
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
          const Divider(height: 32),
          const _QuietHoursSection(),
        ],
      ),
    );
  }
}

/// A single app-wide window during which reminders are held and released at its
/// end instead of arriving overnight (p4.4). Default off; when on, both ends are
/// editable and the window may run past midnight.
class _QuietHoursSection extends ConsumerWidget {
  const _QuietHoursSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiet = ref.watch(quietHoursProvider).value ?? kDefaultQuietHours;
    final controller = ref.read(quietHoursControllerProvider);

    Future<void> pick(bool isStart) async {
      final current = isStart
          ? TimeOfDay(hour: quiet.startHour, minute: quiet.startMinute)
          : TimeOfDay(hour: quiet.endHour, minute: quiet.endMinute);
      final picked = await showTimePicker(
        context: context,
        initialTime: current,
      );
      if (picked == null) return;
      await controller.save(
        isStart
            ? quiet.copyWith(startHour: picked.hour, startMinute: picked.minute)
            : quiet.copyWith(endHour: picked.hour, endMinute: picked.minute),
      );
    }

    return Column(
      children: [
        SwitchListTile(
          value: quiet.enabled,
          title: const Text('Quiet hours'),
          subtitle: const Text(
            'Hold reminders during this window and send them when it ends',
          ),
          onChanged: (value) => controller.save(quiet.copyWith(enabled: value)),
        ),
        if (quiet.enabled) ...[
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Start'),
            subtitle: Text(
              TimeOfDay(
                hour: quiet.startHour,
                minute: quiet.startMinute,
              ).format(context),
            ),
            onTap: () => pick(true),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight_outlined),
            title: const Text('End'),
            subtitle: Text(
              TimeOfDay(
                hour: quiet.endHour,
                minute: quiet.endMinute,
              ).format(context),
            ),
            onTap: () => pick(false),
          ),
        ],
      ],
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
          const _Note(
            "Available once there's enough logged history to predict.",
          )
        else if (enabled)
          _TimeArea(kind: kind, hour: hour, minute: minute),
      ],
    );
  }
}

/// The time control for one enabled category.
///
///  * Fixed-time kinds (`medication` / `bbtPrompt`) — a manual time picker.
///  * Forecast-anchored kinds with a **learned logging hour** (p4.2) — a
///    read-only line with the effective time; the learned hour wins regardless,
///    so a picker here would be a lie.
///  * Forecast-anchored kinds with no learned hour yet — the manual picker plus
///    a caption saying it is only the interim default.
class _TimeArea extends ConsumerWidget {
  const _TimeArea({
    required this.kind,
    required this.hour,
    required this.minute,
  });

  final ReminderKind kind;
  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEventRelativeReminder(kind)) {
      return _Picker(kind: kind, hour: hour, minute: minute);
    }

    final learnedHour = ref.watch(preferredHourProvider).value;
    if (learnedHour != null) {
      final effective = TimeOfDay(hour: learnedHour, minute: 0);
      return ListTile(
        leading: const Icon(Icons.schedule),
        title: Text('Around ${effective.format(context)}'),
        subtitle: const Text('Timed to when you usually log'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Picker(kind: kind, hour: hour, minute: minute),
        const _Note(
          "Until you've logged enough, we'll send these around this time.",
        ),
      ],
    );
  }
}

class _Picker extends ConsumerWidget {
  const _Picker({required this.kind, required this.hour, required this.minute});

  final ReminderKind kind;
  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: const Text('Time'),
      subtitle: Text(TimeOfDay(hour: hour, minute: minute).format(context)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          await ref
              .read(reminderControllerProvider)
              .setTime(kind, hour: picked.hour, minute: picked.minute);
        }
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
      child: Align(alignment: Alignment.centerLeft, child: Text(text)),
    );
  }
}
