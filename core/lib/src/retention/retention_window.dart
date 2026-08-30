/// Scheduled auto-deletion window (p2.3).
///
/// The user picks how long to keep dated entries; anything older is purged
/// automatically (see [RetentionService]). `off` is the default and keeps
/// everything. Requirement refs: `requirements.md` §3, §7, §9(11).
library;

/// How long dated entries are kept before automatic deletion.
enum RetentionWindow {
  /// Keep everything until the user deletes it themselves. Default.
  off,
  months6,
  year1,
  years2,
  years3;

  /// The oldest calendar date kept for [now]: entries strictly before this are
  /// purged. `null` when [off]. Built from a fresh local midnight (calendar
  /// arithmetic, DST-safe) rather than subtracting a fixed `Duration`.
  DateTime? cutoff(DateTime now) => switch (this) {
    RetentionWindow.off => null,
    RetentionWindow.months6 => DateTime(now.year, now.month - 6, now.day),
    RetentionWindow.year1 => DateTime(now.year - 1, now.month, now.day),
    RetentionWindow.years2 => DateTime(now.year - 2, now.month, now.day),
    RetentionWindow.years3 => DateTime(now.year - 3, now.month, now.day),
  };

  /// Short label for the settings picker.
  String get label => switch (this) {
    RetentionWindow.off => 'Off',
    RetentionWindow.months6 => 'After 6 months',
    RetentionWindow.year1 => 'After 1 year',
    RetentionWindow.years2 => 'After 2 years',
    RetentionWindow.years3 => 'After 3 years',
  };

  /// The token stored in `app_settings` (the enum name).
  String get storageToken => name;

  /// Parse a stored token. Anything unrecognised (including `null`) → [off].
  static RetentionWindow fromStorage(String? token) {
    for (final w in RetentionWindow.values) {
      if (w.name == token) return w;
    }
    return RetentionWindow.off;
  }
}
