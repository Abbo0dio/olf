import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screen_security.dart';

/// Key on the opaque cover, so widget tests can assert when it is showing.
@visibleForTesting
const Key privacyShieldCoverKey = Key('olf.privacy-shield.cover');

/// Wraps the whole app from `MaterialApp.builder` and provides two §3 / §7
/// "background privacy" guarantees (p2.4):
///
///  * **App-switcher mask** — whenever the app is not `resumed` an opaque,
///    content-free cover is painted over everything. The OS snapshot used for
///    the task switcher (and for transient interruptions like Control Centre or
///    the notification shade) therefore never shows real data. Cross-platform;
///    on iOS a matching native cover in `AppDelegate` is the belt-and-braces.
///  * **Screen-capture block** — holds [ScreenSecurity.setSecure] `true` for the
///    lifetime of the app (Android `FLAG_SECURE`; a no-op on iOS).
///
/// The masked child stays mounted the whole time, so navigation, scroll offset
/// and form state are all preserved when the app returns to the foreground.
class PrivacyShield extends ConsumerStatefulWidget {
  const PrivacyShield({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends ConsumerState<PrivacyShield> {
  late final AppLifecycleListener _listener;
  late final ScreenSecurity _screenSecurity;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onLifecycleState);
    // Grab the seam now so `dispose` never has to touch `ref`.
    _screenSecurity = ref.read(screenSecurityProvider);
    // Fire-and-forget: engage the capture block as soon as the app is up.
    _screenSecurity.setSecure(true);
  }

  void _onLifecycleState(AppLifecycleState state) {
    final shouldObscure = state != AppLifecycleState.resumed;
    if (shouldObscure != _obscured) {
      setState(() => _obscured = shouldObscure);
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    // Best effort — the process is usually going away anyway.
    _screenSecurity.setSecure(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `StackFit.expand` so the app keeps tight, full-screen constraints — a bare
    // Stack would hand the Navigator loose constraints and collapse the layout.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_obscured)
          const Positioned.fill(child: ExcludeSemantics(child: _ShieldCover())),
      ],
    );
  }
}

class _ShieldCover extends StatelessWidget {
  const _ShieldCover();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: privacyShieldCoverKey,
      color: scheme.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'olf',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
