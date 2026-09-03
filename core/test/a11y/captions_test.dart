import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p5.2 — the compile-time captions gate. These tests pin the runtime half:
/// the value types reject a malformed caption track, an empty transcript, and
/// a blank language code, so a future Phase 11 media slice cannot slip past
/// the contract with degenerate data.
void main() {
  CaptionCue cue(int startMs, int endMs, [String text = 'hello']) => CaptionCue(
    start: Duration(milliseconds: startMs),
    end: Duration(milliseconds: endMs),
    text: text,
  );

  group('CaptionCue', () {
    test('accepts a well-formed cue and reports its duration', () {
      final c = cue(1000, 2500);
      expect(c.duration, const Duration(milliseconds: 1500));
    });

    test('rejects a negative start', () {
      expect(
        () => CaptionCue(
          start: const Duration(milliseconds: -1),
          end: const Duration(seconds: 1),
          text: 'x',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects end == start and end < start', () {
      expect(() => cue(1000, 1000), throwsA(isA<AssertionError>()));
      expect(() => cue(2000, 1000), throwsA(isA<AssertionError>()));
    });

    test('rejects blank text', () {
      expect(() => cue(0, 1000, '   '), throwsA(isA<AssertionError>()));
    });

    test('value equality', () {
      expect(cue(0, 1000), cue(0, 1000));
      expect(cue(0, 1000), isNot(cue(0, 1001)));
    });
  });

  group('CaptionTrack', () {
    test('accepts an ordered, non-overlapping track', () {
      final t = CaptionTrack(
        languageCode: 'en',
        cues: [cue(0, 1000), cue(1000, 2000), cue(2500, 3000)],
      );
      expect(t.cues, hasLength(3));
      expect(t.languageCode, 'en');
    });

    test('rejects an empty cue list', () {
      expect(
        () => CaptionTrack(languageCode: 'en', cues: []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a blank language code', () {
      expect(
        () => CaptionTrack(languageCode: '  ', cues: [cue(0, 1000)]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects out-of-order cues', () {
      expect(
        () => CaptionTrack(
          languageCode: 'en',
          cues: [cue(2000, 3000), cue(0, 1000)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects overlapping cues', () {
      expect(
        () => CaptionTrack(
          languageCode: 'en',
          cues: [cue(0, 1500), cue(1000, 2000)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('exposes an unmodifiable cue list', () {
      final t = CaptionTrack(languageCode: 'en', cues: [cue(0, 1000)]);
      expect(() => t.cues.add(cue(1000, 2000)), throwsUnsupportedError);
    });

    test('value equality over language + cues', () {
      final a = CaptionTrack(languageCode: 'en', cues: [cue(0, 1000)]);
      final b = CaptionTrack(languageCode: 'en', cues: [cue(0, 1000)]);
      final c = CaptionTrack(languageCode: 'fr', cues: [cue(0, 1000)]);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('MediaItem', () {
    CaptionTrack track() =>
        CaptionTrack(languageCode: 'en', cues: [cue(0, 1000, 'Welcome.')]);

    test('constructs only with both a caption track and a transcript', () {
      final item = MediaItem(
        id: 'intro-to-cycles',
        title: 'Intro to cycles',
        captions: track(),
        transcript: 'Welcome. This short video explains the menstrual cycle.',
      );
      expect(item.captions.cues, hasLength(1));
      expect(item.transcript, isNotEmpty);
    });

    test('rejects an empty / whitespace transcript', () {
      expect(
        () => MediaItem(
          id: 'x',
          title: 'x',
          captions: track(),
          transcript: '   ',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a blank id or title', () {
      expect(
        () =>
            MediaItem(id: '', title: 'x', captions: track(), transcript: 'ok'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MediaItem(
          id: 'x',
          title: '  ',
          captions: track(),
          transcript: 'ok',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('value equality', () {
      final a = MediaItem(
        id: 'x',
        title: 'X',
        captions: track(),
        transcript: 'ok',
      );
      final b = MediaItem(
        id: 'x',
        title: 'X',
        captions: track(),
        transcript: 'ok',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
