import 'package:olf_core/olf_core.dart';

/// **Settings-facing** labels for the per-category reminders (p4.1).
///
/// These are shown only inside the unlocked app — the Settings → Notifications
/// list — so they can name plainly what each reminder is about. They must still
/// be gender-neutral (p1.9 lint).
///
/// The strings that can land on a lock screen — notification titles and bodies —
/// live in `notification_copy.dart` under much stricter rules (p4.3).

/// The Settings → Notifications row title for [kind].
String reminderCategoryTitle(ReminderKind kind) => switch (kind) {
  ReminderKind.medication => 'Daily reminder',
  ReminderKind.bbtPrompt => 'Morning temperature',
  ReminderKind.upcomingPeriod => 'Upcoming period',
  ReminderKind.fertileWindow => 'Fertile window',
  ReminderKind.latePeriodCheckIn => 'Late period check-in',
};

/// The Settings → Notifications row sub-label for [kind] — an honest one-liner
/// describing when it fires.
String reminderCategorySubtitle(ReminderKind kind) => switch (kind) {
  ReminderKind.medication => 'Every day at a time you choose',
  ReminderKind.bbtPrompt => 'Every day at a time you choose',
  ReminderKind.upcomingPeriod => 'About 2 days before your predicted start',
  ReminderKind.fertileWindow =>
    'Around when your fertile window is estimated to begin',
  ReminderKind.latePeriodCheckIn =>
    "If your period hasn't been logged 2 days after it was expected",
};

/// Order the categories are shown in Settings.
const List<ReminderKind> reminderCategoryOrder = [
  ReminderKind.upcomingPeriod,
  ReminderKind.fertileWindow,
  ReminderKind.latePeriodCheckIn,
  ReminderKind.medication,
  ReminderKind.bbtPrompt,
];
