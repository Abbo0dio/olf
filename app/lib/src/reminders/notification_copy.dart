import 'package:olf_core/olf_core.dart';

/// Every user-facing string that can land in an OS notification (p4.3).
///
/// These sit on a **lock screen**, visible to anyone holding the phone, so the
/// rules are strict and enforced by `notification_copy_test.dart`:
///
///  * no medication / method / device name, no diagnosis word, no "pregnan…",
///    nothing that names a cycle phase or a symptom — the notification must not
///    reveal *why* olf is installed;
///  * non-alarming and non-clinical — a gentle nudge, never a warning;
///  * invitational, never interrogative or a command — "when you're ready, you
///    can…", never "log it now" or "has it started?";
///  * gender-neutral second person ("you"), no exclamation-mark urgency;
///  * short enough to read at a glance.
///
/// The **title is the same for every kind** — a per-kind title such as
/// "Fertile window" would itself expose health state on the lock screen, which
/// is the very thing this file exists to prevent.
///
/// Settings-facing labels (`reminderCategoryTitle` / `reminderCategorySubtitle`
/// / `reminderCategoryOrder`) are a different audience — shown only inside the
/// unlocked app — and stay in `reminder_copy.dart`.

/// The notification title for every reminder kind: the bare app name, nothing
/// that hints at content.
const String notificationTitle = 'olf';

/// p1.7's daily-reminder body. **Kept byte-identical** — the medication path is
/// unchanged by p4.3. Generic "check-in": names no medication, dose or method.
const String medicationReminderBody = 'Time for your daily check-in.';

/// Morning basal-temperature prompt. "Morning note", never "temperature" / "BBT".
const String bbtPromptReminderBody = 'A gentle nudge for your morning note.';

/// A few days before the predicted period. Forward-looking and unnamed — no
/// "period", no count of days.
const String upcomingPeriodReminderBody =
    'A quick heads-up for the days ahead.';

/// Around the start of the estimated fertile window. Warm and unnamed — no
/// "fertile" / "ovulation".
const String fertileWindowReminderBody =
    'A gentle check-in — open olf whenever you have a moment.';

/// The period is later than expected and nothing has been logged. Deliberately
/// **invitational, not interrogative** — no "has it started?", no "log it now".
/// It offers, it does not collect homework.
const String latePeriodCheckInReminderBody =
    "When you're ready, you can open olf to update your dates.";

/// Title + body for a fired notification of [kind].
({String title, String body}) notificationCopyFor(ReminderKind kind) => (
  title: notificationTitle,
  body: switch (kind) {
    ReminderKind.medication => medicationReminderBody,
    ReminderKind.bbtPrompt => bbtPromptReminderBody,
    ReminderKind.upcomingPeriod => upcomingPeriodReminderBody,
    ReminderKind.fertileWindow => fertileWindowReminderBody,
    ReminderKind.latePeriodCheckIn => latePeriodCheckInReminderBody,
  },
);
