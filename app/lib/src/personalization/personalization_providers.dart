import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// The user's pronouns for copy (p1.9), live. [Pronouns.unspecified] until the
/// database is open or the user picks — which `formsFor` resolves to they/them.
final pronounsProvider = StreamProvider<Pronouns>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) {
    return Stream<Pronouns>.value(Pronouns.unspecified);
  }
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.pronouns)
      .map(pronounsFromStorage);
});

/// Persist [pronouns].
Future<void> setPronouns(WidgetRef ref, Pronouns pronouns) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.pronouns, pronounsToStorage(pronouns));
