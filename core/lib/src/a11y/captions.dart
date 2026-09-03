import 'package:meta/meta.dart';

/// Caption + transcript value types and the [MediaItem] contract (p5.2).
///
/// olf has **no media subsystem yet**. These types exist now so that when
/// Phase 11 adds in-app video/audio it cannot compile without synchronised
/// captions *and* a plain-text transcript — WCAG 2.2 SC 1.2.2 (Captions),
/// 1.2.3 (Media Alternative), 1.2.5 (Audio Description). The gate is the
/// non-nullable `required` fields on [MediaItem]; the constructors additionally
/// assert their contents are well-formed.
///
/// Pure Dart — no Flutter, no `DateTime.now()` (a `Duration` offset from the
/// media's own start is all a cue needs).

/// One timed caption line: [text] is shown from [start] to [end], both measured
/// as offsets from the start of the media.
@immutable
class CaptionCue {
  CaptionCue({required this.start, required this.end, required this.text})
    : assert(start >= Duration.zero, 'cue start must not be negative'),
      assert(end > start, 'cue end must be strictly after start'),
      assert(text.trim().isNotEmpty, 'cue text must not be blank');

  final Duration start;
  final Duration end;
  final String text;

  /// How long this cue is on screen.
  Duration get duration => end - start;

  @override
  bool operator ==(Object other) =>
      other is CaptionCue &&
      other.start == start &&
      other.end == end &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'CaptionCue($start–$end: "$text")';
}

/// A full caption track in one language: a non-empty, chronological,
/// non-overlapping list of [cues].
@immutable
class CaptionTrack {
  CaptionTrack({required this.languageCode, required List<CaptionCue> cues})
    : cues = List<CaptionCue>.unmodifiable(cues),
      assert(languageCode.trim().isNotEmpty, 'languageCode must not be blank'),
      assert(cues.isNotEmpty, 'a caption track must have at least one cue'),
      assert(
        _isChronological(cues),
        'cues must be in start order and must not overlap',
      );

  /// BCP-47 language tag for the caption text, e.g. `en`, `en-US`, `pt-BR`.
  final String languageCode;

  /// Ordered, non-overlapping cues. Unmodifiable.
  final List<CaptionCue> cues;

  static bool _isChronological(List<CaptionCue> cues) {
    for (var i = 1; i < cues.length; i++) {
      if (cues[i].start < cues[i - 1].end) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is CaptionTrack &&
      other.languageCode == languageCode &&
      _cuesEqual(other.cues, cues);

  @override
  int get hashCode => Object.hash(languageCode, Object.hashAll(cues));

  @override
  String toString() =>
      'CaptionTrack($languageCode, ${cues.length} cue${cues.length == 1 ? '' : 's'})';
}

bool _cuesEqual(List<CaptionCue> a, List<CaptionCue> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The contract every piece of Phase 11 media content must satisfy before olf
/// will display it: a synchronised [captions] track **and** a plain-text
/// [transcript], both mandatory.
///
/// There is no player yet. This type is the compile-time half of the p5.2
/// gate — a Phase 11 media slice cannot construct a [MediaItem] (and the app's
/// `CaptionedMedia` widget cannot be built) without supplying both. See
/// `docs/accessibility-conformance.md` (SC 1.2.1–1.2.5).
@immutable
class MediaItem {
  MediaItem({
    required this.id,
    required this.title,
    required this.captions,
    required this.transcript,
  }) : assert(id.trim().isNotEmpty, 'MediaItem id must not be blank'),
       assert(title.trim().isNotEmpty, 'MediaItem title must not be blank'),
       assert(
         transcript.trim().isNotEmpty,
         'MediaItem transcript must not be empty — a caption track alone is '
         'not a media alternative (WCAG 1.2.3)',
       );

  /// Stable identifier for the content item.
  final String id;

  /// Human-readable title, shown alongside the media.
  final String title;

  /// Synchronised captions. Non-nullable by design.
  final CaptionTrack captions;

  /// Full plain-text transcript (dialogue + relevant non-speech information).
  /// Non-nullable by design.
  final String transcript;

  @override
  bool operator ==(Object other) =>
      other is MediaItem &&
      other.id == id &&
      other.title == title &&
      other.captions == captions &&
      other.transcript == transcript;

  @override
  int get hashCode => Object.hash(id, title, captions, transcript);

  @override
  String toString() => 'MediaItem($id: "$title", ${captions.cues.length} cues)';
}
