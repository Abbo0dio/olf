import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/a11y/captioned_media.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

/// p5.2 — `CaptionedMedia` is the widget-layer half of the captions gate. Its
/// constructor takes a `required CaptionTrack` and a `required String`
/// transcript (the compile-time gate — omitting either is a build error), and
/// today it only renders a "coming later" placeholder in either theme.
void main() {
  CaptionTrack track() => CaptionTrack(
    languageCode: 'en',
    cues: [
      CaptionCue(
        start: Duration.zero,
        end: const Duration(seconds: 2),
        text: 'Welcome.',
      ),
    ],
  );

  Widget host(Brightness brightness, Widget child) => MaterialApp(
    theme: olfTheme(brightness),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders the non-playable placeholder with its title', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Brightness.light,
        CaptionedMedia(
          captions: track(),
          transcript: 'Welcome. A short explainer.',
          title: 'Intro to cycles',
        ),
      ),
    );

    expect(find.text('Intro to cycles'), findsOneWidget);
    expect(
      find.text('This content is coming in a later version.'),
      findsOneWidget,
    );
    // Nothing playable: no transport controls, no scrubber.
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly in dark mode', (tester) async {
    await tester.pumpWidget(
      host(
        Brightness.dark,
        CaptionedMedia(captions: track(), transcript: 'transcript text'),
      ),
    );
    expect(
      find.text('This content is coming in a later version.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes a semantics label for the placeholder', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Brightness.light,
        CaptionedMedia(
          captions: track(),
          transcript: 't',
          title: 'Fertility basics',
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Media placeholder: Fertility basics'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('CaptionedMedia.fromItem carries the MediaItem contract', (
    tester,
  ) async {
    final item = MediaItem(
      id: 'm1',
      title: 'Understanding ovulation',
      captions: track(),
      transcript: 'A full transcript of the clip.',
    );
    await tester.pumpWidget(
      host(Brightness.light, CaptionedMedia.fromItem(item)),
    );
    expect(find.text('Understanding ovulation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
