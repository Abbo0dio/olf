import 'package:flutter/material.dart';

/// One shared empty-state treatment for the app (r5b): a discreet leading icon
/// + a single low-emphasis line, with an optional call-to-action button.
///
/// Replaces the bare `Text('…')` empty states across the app so every "nothing
/// here yet" reads the same. The icon is purely decorative (no semantics —
/// nothing new is spoken, so `reduceSpokenDetail` has nothing extra to redact);
/// the message text is unchanged at every call site.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = kEmptyStateDefaultIcon,
    this.ctaLabel,
    this.onCta,
  });

  /// The empty-state line. Copy is owned by the caller (per-site copy is
  /// preserved verbatim — this widget only adds the chrome).
  final String message;

  /// The leading icon. Defaults to the neutral outlined spot; callers override
  /// for a site-specific glyph (temperature, calendar, medication, …).
  final IconData icon;

  /// Optional call-to-action. Render only when both [ctaLabel] and [onCta] are
  /// given.
  final String? ctaLabel;

  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: onColor),
            const SizedBox(width: 8),
            // Expanded so a long line wraps instead of pushing off-screen
            // (also at the 2.0× text-scale sweep).
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
              ),
            ),
          ],
        ),
        if (ctaLabel != null && onCta != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: onCta,
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(ctaLabel!),
            ),
          ),
      ],
    );
  }
}

/// The neutral "empty slot" glyph every site starts from.
const IconData kEmptyStateDefaultIcon = Icons.event_available_outlined;
