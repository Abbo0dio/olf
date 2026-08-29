import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../settings/settings_providers.dart';

/// Whether the first-run privacy explainer has been acknowledged (p1.8).
///
/// Backed by the `onboarding_complete` key in `app_settings` (the reusable
/// prefs store). `AppGate` shows the explainer until this resolves to `true`;
/// re-read via `ref.invalidate` once the user continues.
final firstRunDoneProvider = FutureProvider<bool>((ref) async {
  final value = await ref
      .watch(settingsRepositoryProvider)
      .get(SettingKeys.onboardingComplete);
  return value == 'true';
});
