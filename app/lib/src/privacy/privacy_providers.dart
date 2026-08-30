import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// The user's opt-in to on-device usage analytics (p2.5). `false` until the
/// database is open or the user turns it on — olf collects nothing while off.
final analyticsOptInProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.analyticsOptIn)
      .map((value) => value == 'true');
});

/// The user's opt-in to sharing data with third parties (p2.5). `false` by
/// default; olf shares nothing regardless of this today.
final dataSharingOptInProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.dataSharingOptIn)
      .map((value) => value == 'true');
});

/// Set the analytics opt-in. Independent of [setDataSharingOptIn].
Future<void> setAnalyticsOptIn(WidgetRef ref, {required bool value}) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.analyticsOptIn, value ? 'true' : 'false');

/// Set the data-sharing opt-in. Independent of [setAnalyticsOptIn].
Future<void> setDataSharingOptIn(WidgetRef ref, {required bool value}) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.dataSharingOptIn, value ? 'true' : 'false');
