import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_gate.dart';
import 'src/reminders/local_notification_reminder_scheduler.dart';
import 'src/security/privacy_shield.dart';
import 'src/theme/olf_theme.dart';
import 'src/theme/theme_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort: prime the local-notification wrapper so an already-enabled
  // reminder keeps firing. Failure here (no plugin, denied platform) must not
  // stop the app — everything else works fully offline.
  try {
    await LocalNotificationReminderScheduler.instance.ensureInitialized();
  } catch (_) {
    // ignored — the reminder screen still works; scheduling just no-ops.
  }
  runApp(const ProviderScope(child: OlfApp()));
}

/// Root of the olf app.
///
/// Neutral, discreet, non-gendered theme (see `theme/olf_theme.dart`) with a
/// user-selectable light/dark override (p1.9).
class OlfApp extends ConsumerWidget {
  const OlfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp(
      title: 'olf',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: olfTheme(Brightness.light),
      darkTheme: olfTheme(Brightness.dark),
      // p2.4: mask the app-switcher snapshot when backgrounded and hold the
      // Android screen-capture block. Wrapped here (not at `home`) so it also
      // covers dialogs and pushed routes.
      builder: (context, child) =>
          PrivacyShield(child: child ?? const SizedBox.shrink()),
      home: const AppGate(),
    );
  }
}
