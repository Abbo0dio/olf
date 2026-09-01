import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// `app_settings` holds opaque strings, so the app owns the [QuietHours]
/// encoding. Format: `enabled;startH:startM;endH:endM`, e.g. `1;22:0;7:0`.
String encodeQuietHours(QuietHours q) =>
    '${q.enabled ? 1 : 0};${q.startHour}:${q.startMinute};'
    '${q.endHour}:${q.endMinute}';

/// Inverse of [encodeQuietHours]. Any malformed or absent value decodes to
/// [kDefaultQuietHours] — a bad string must never brick reminders.
QuietHours decodeQuietHours(String? raw) {
  if (raw == null || raw.isEmpty) return kDefaultQuietHours;
  try {
    final parts = raw.split(';');
    final start = parts[1].split(':');
    final end = parts[2].split(':');
    return QuietHours(
      enabled: parts[0] == '1',
      startHour: int.parse(start[0]),
      startMinute: int.parse(start[1]),
      endHour: int.parse(end[0]),
      endMinute: int.parse(end[1]),
    );
  } catch (_) {
    return kDefaultQuietHours;
  }
}

/// The stored quiet-hours window, live. [kDefaultQuietHours] (disabled) until the
/// database is open or the user changes it.
final quietHoursProvider = StreamProvider<QuietHours>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) {
    return Stream<QuietHours>.value(kDefaultQuietHours);
  }
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.quietHours)
      .map(decodeQuietHours);
});

/// Writes the quiet-hours window. The reminder-scheduling paths re-read
/// [quietHoursProvider] on their next pass, so a change takes effect when a
/// reminder is next (re)armed.
final quietHoursControllerProvider = Provider<QuietHoursController>(
  (ref) => QuietHoursController(ref.watch(settingsRepositoryProvider)),
);

class QuietHoursController {
  QuietHoursController(this._settings);

  final SettingsRepository _settings;

  Future<void> save(QuietHours window) =>
      _settings.set(SettingKeys.quietHours, encodeQuietHours(window));
}
