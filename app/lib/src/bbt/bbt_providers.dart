import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// Per-day basal temperature CRUD over the opened database.
final bbtRepositoryProvider = Provider<BbtRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftBbtRepository(db);
});

/// Every logged basal temperature, live. Not `autoDispose` — the home screen
/// chart listens; same reasoning as `dailyFlowsProvider`.
final bbtEntriesProvider = StreamProvider<List<BbtEntry>>((ref) {
  return ref.watch(bbtRepositoryProvider).watchAll();
});

/// The preferred display unit for basal temperatures, live. Defaults to Celsius
/// until the user picks otherwise (stored in `app_settings`).
final temperatureUnitProvider = StreamProvider<TemperatureUnit>((ref) {
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.temperatureUnit)
      .map(TemperatureUnitInfo.fromStorage);
});
