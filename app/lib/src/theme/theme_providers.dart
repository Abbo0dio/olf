import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// The manual light/dark override (p1.9), live. `system` until the database is
/// open or the user picks otherwise. Stored in `app_settings`.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<ThemeMode>.value(ThemeMode.system);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.themeMode)
      .map(themeModeFromStorage);
});

/// Persist [mode].
Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) =>
    ref.read(settingsRepositoryProvider).set(SettingKeys.themeMode, mode.name);

/// Parse the stored token. Anything unrecognised → [ThemeMode.system].
ThemeMode themeModeFromStorage(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Short label for the picker.
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};
