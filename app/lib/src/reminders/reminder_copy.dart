import 'package:olf_core/olf_core.dart';

import 'reminder_scheduler.dart';

/// User-facing strings for the per-category reminders (p4.1).
///
/// Two audiences, two different rules:
///
///  * **Notification** title/body ([notificationCopyFor]) can land on a lock
///    screen, so every kind's wording is deliberately vague — no health noun, no
///    imperative, no urgency. p4.3 does the full copy pass; these are safe
///    placeholders locked behind `notification_copy_test.dart`.
///  * **Settings** labels ([reminderCategoryTitle] / [reminderCategorySubtitle])
///    are only ever shown inside the app, so they can name what the reminder is
///    about plainly. They must still be gender-neutral (p1.9 lint).

/// Every notification uses the bare app name as its title — nothing else is
/// safe on a lock screen.
const String reminderTitle = reminderNotificationTitle;

/// p1.7's medication body, kept verbatim so that path is byte-identical.
const String medicationReminderBody = reminderNotificationBody;
const String bbtPromptReminderBody = 'A gentle nudge for your morning note.';
const String upcomingPeriodReminderBody =
    'A quick heads-up for the days ahead.';
const String fertileWindowReminderBody = 'A note to check in with olf.';
const String latePeriodCheckInReminderBody =
    'When you have a moment, you can open olf to update things.';

/// Title + body for a fired notification of [kind].
({String title, String body}) notificationCopyFor(ReminderKind kind) => (
  title: reminderTitle,
  body: switch (kind) {
    ReminderKind.medication => medicationReminderBody,
    ReminderKind.bbtPrompt => bbtPromptReminderBody,
    ReminderKind.upcomingPeriod => upcomingPeriodReminderBody,
    ReminderKind.fertileWindow => fertileWindowReminderBody,
    ReminderKind.latePeriodCheckIn => latePeriodCheckInReminderBody,
  },
);

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
