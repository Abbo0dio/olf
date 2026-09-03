import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

/// Placeholder for Phase 11 in-app media.
///
/// Constructing it **requires** a [CaptionTrack] and a plain-text [transcript]
/// — the p5.2 captions gate at the widget layer (mirrors `core`'s [MediaItem]
/// contract). Nothing here plays: it renders a small, theme-aware,
/// gender-neutral "coming later" panel. When Phase 11 adds a real player it
/// replaces the body of `build` and keeps this constructor signature, so no
/// media can reach the screen without captions + a transcript.
class CaptionedMedia extends StatelessWidget {
  const CaptionedMedia({
    super.key,
    required this.captions,
    required this.transcript,
    this.title,
  });

  /// Synchronised captions for the media. Mandatory.
  final CaptionTrack captions;

  /// Full text transcript of the media. Mandatory, non-empty.
  final String transcript;

  /// Optional label shown on the placeholder.
  final String? title;

  /// Convenience constructor from a [MediaItem].
  CaptionedMedia.fromItem(MediaItem item, {Key? key})
    : this(
        key: key,
        captions: item.captions,
        transcript: item.transcript,
        title: item.title,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title == null ? 'Media placeholder' : 'Media placeholder: $title',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.movie_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title ?? 'Media',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This content is coming in a later version.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
