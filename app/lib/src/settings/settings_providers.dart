import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';

/// The persistent key/value preferences store (`app_settings`). Only valid
/// inside the `data` branch of the database gate (see [appDatabaseProvider]).
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftSettingsRepository(db);
});
