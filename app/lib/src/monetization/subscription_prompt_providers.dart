import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// Whether subscription / upsell / paid-tier prompts may be shown (p4.5).
///
/// Live `bool`, **default `true`**. This is the single hard gate every paid-tier
/// prompt added in Phase 10 or later must check — see
/// `docs/monetization-principles.md`. No such prompt exists yet; this
/// establishes the suppression path as an enforceable principle now.
final subscriptionPromptsAllowedProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(true);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.suppressSubscriptionPrompts)
      .map(subscriptionPromptsAllowed);
});

/// Persist the user's choice to permanently hide subscription offers.
///
/// Turning it on is immediate and final until the user turns it back off — no
/// confirmation dialog, no "are you sure you'll miss out", no re-prompt.
Future<void> setSubscriptionPromptsSuppressed(
  WidgetRef ref, {
  required bool suppressed,
}) => ref
    .read(settingsRepositoryProvider)
    .set(
      SettingKeys.suppressSubscriptionPrompts,
      suppressed ? 'true' : 'false',
    );
