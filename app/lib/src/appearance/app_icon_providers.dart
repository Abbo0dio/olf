import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';
import 'app_icon.dart';

/// The active home-screen icon (p5.4), live. [AppIconOption.branded] until the
/// database is open or the user picks otherwise. Stored in `app_settings`.
final appIconProvider = StreamProvider<AppIconOption>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) {
    return Stream<AppIconOption>.value(AppIconOption.branded);
  }
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.appIcon)
      .map(AppIconOption.fromStorage);
});

/// Switch the launcher icon to [option]: ask the platform first, and only
/// persist the choice once the platform call succeeds (so a failed switch
/// leaves both the icon and the stored preference on the previous value).
///
/// Rethrows [AppIconException] on failure — the caller shows the message.
Future<void> setAppIcon(WidgetRef ref, AppIconOption option) async {
  await ref.read(appIconRepositoryProvider).apply(option);
  await ref
      .read(settingsRepositoryProvider)
      .set(SettingKeys.appIcon, option.id);
}
