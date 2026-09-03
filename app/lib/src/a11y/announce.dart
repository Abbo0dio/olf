import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

/// Speak [message] on the screen reader without moving focus — a live-region
/// style announcement (WCAG 2.2 SC 4.1.3 Status Messages).
///
/// Introduced for the p5.3 auto-lock warning; the p3.3 correction notice also
/// routes through it. Deferred until after the current frame so it fires once
/// the triggering widget is on screen. Safe to call with a possibly-unmounted
/// [context] — it checks before reading directionality.
void announce(BuildContext context, String message) {
  if (message.trim().isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final direction = context.mounted
        ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
        : TextDirection.ltr;
    SemanticsService.announce(message, direction);
  });
}
