/// An app-wide "do not deliver" window (p4.4): a single nightly-style span
/// during which olf holds its notifications and releases them at the window's
/// end instead of dropping them.
///
/// Wall-clock only — no time zone, exactly like [nextOccurrence] /
/// `nextFireTime` / `learnPreferredHour`. The window may wrap past midnight
/// (e.g. 22:00 → 07:00).
class QuietHours {
  const QuietHours({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.enabled,
  });

  /// Window start, local wall clock. 0–23 / 0–59.
  final int startHour;
  final int startMinute;

  /// Window end, local wall clock. 0–23 / 0–59. When `end <= start` the window
  /// wraps over midnight.
  final int endHour;
  final int endMinute;

  /// When `false`, [applyQuietHours] is a pass-through — nothing is held.
  final bool enabled;

  QuietHours copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    bool? enabled,
  }) => QuietHours(
    startHour: startHour ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour: endHour ?? this.endHour,
    endMinute: endMinute ?? this.endMinute,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startHour == startHour &&
      other.startMinute == startMinute &&
      other.endHour == endHour &&
      other.endMinute == endMinute &&
      other.enabled == enabled;

  @override
  int get hashCode =>
      Object.hash(startHour, startMinute, endHour, endMinute, enabled);

  @override
  String toString() =>
      'QuietHours('
      '${startHour.toString().padLeft(2, '0')}:'
      '${startMinute.toString().padLeft(2, '0')}–'
      '${endHour.toString().padLeft(2, '0')}:'
      '${endMinute.toString().padLeft(2, '0')}, '
      '${enabled ? 'on' : 'off'})';
}

/// The window every reader falls back to when nothing is stored, and the one the
/// Settings screen shows the first time it is opened. Disabled, so it changes
/// nothing until the user turns it on.
const QuietHours kDefaultQuietHours = QuietHours(
  startHour: 22,
  startMinute: 0,
  endHour: 7,
  endMinute: 0,
  enabled: false,
);

/// If [candidate] falls inside [quietHours], the next instant at the window's
/// end; otherwise [candidate] unchanged.
///
/// Pure and deterministic — no `DateTime.now()`, no time zone. Rules:
///
///  * `!quietHours.enabled` ⇒ [candidate] unchanged.
///  * A zero-width window (`start == end`) holds nothing ⇒ [candidate] unchanged.
///  * The window is half-open: a candidate **exactly at the start** is inside;
///    one **exactly at the end** is outside.
///  * A window with `end <= start` wraps past midnight. A candidate in the
///    pre-midnight part is shifted to the window end on the **next** calendar
///    day; one in the post-midnight part to the window end on the **same** day.
///  * The returned instant carries seconds and milliseconds zeroed.
DateTime applyQuietHours(DateTime candidate, QuietHours quietHours) {
  if (!quietHours.enabled) return candidate;

  final start = quietHours.startHour * 60 + quietHours.startMinute;
  final end = quietHours.endHour * 60 + quietHours.endMinute;
  if (start == end) return candidate;

  final t = candidate.hour * 60 + candidate.minute;
  final wraps = start > end;
  final inside = wraps ? (t >= start || t < end) : (t >= start && t < end);
  if (!inside) return candidate;

  // For a wrapping window the end is on the following day only when the
  // candidate is still before midnight (the `t >= start` part of the span).
  final endIsNextDay = wraps && t >= start;
  return DateTime(
    candidate.year,
    candidate.month,
    candidate.day + (endIsNextDay ? 1 : 0),
    quietHours.endHour,
    quietHours.endMinute,
  );
}
