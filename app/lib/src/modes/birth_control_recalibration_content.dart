import 'support_resources_content.dart';

/// Bundled, non-clinical explainer text for the birth-control-switching
/// recalibration state (p7.8).
///
/// Kept as data (not inline in the widget) so a content test can assert the
/// required lines are present and the copy sweep has one place to look. Tone:
/// plain, second person, never prescriptive, no diagnosis. No external links
/// that phone home — there are none at all here. Reviewed against
/// `docs/inclusive-language.md` and the p4.3 sensitive-copy discipline.
class BirthControlRecalibrationContent {
  const BirthControlRecalibrationContent({
    required this.title,
    required this.intro,
    required this.sections,
    required this.findCareLine,
  });

  final String title;
  final String intro;
  final List<({String heading, String body})> sections;

  /// The line pointing to real care — always shown, last before the disclaimer.
  final String findCareLine;

  /// The fixed not-a-medical-device line every mode screen carries (§6).
  static const String notMedicalDeviceLine =
      SupportResources.notMedicalDeviceLine;

  /// The short note shown on the prediction surface while recalibration is
  /// active. Generic on purpose — it never names a method or a diagnosis.
  static const String predictionCardNote =
      'Your cycle may be settling after a birth-control change. Predictions '
      'will be less certain for a while.';
}

/// The one explainer, used for both starting and stopping — the difference is
/// spelled out in the body rather than by branching the whole screen, because
/// the maths and the disclaimer are identical either way.
const BirthControlRecalibrationContent
birthControlRecalibrationContent = BirthControlRecalibrationContent(
  title: 'After a birth-control change',
  intro:
      'Starting or stopping hormonal birth control changes the signals your '
      'cycle is built from. For a while, what you log may not line up with '
      'your longer-term pattern, so olf holds back a confident forecast and '
      'shows this note instead. Take what is useful here and leave the rest.',
  sections: [
    (
      heading: 'If you just started',
      body:
          'Any bleeding you have on hormonal birth control is usually a '
          'withdrawal bleed — a response to the hormones in the method, not '
          'a true period driven by ovulation. It can be lighter, shorter, '
          'or arrive on a different schedule, and the first few months are '
          'often the most changeable as your body adjusts.',
    ),
    (
      heading: 'If you just stopped',
      body:
          'It can take a few weeks to a few months for ovulation and true '
          'periods to return, and the first cycles back are often longer or '
          'more variable than they will settle to. This is common and not a '
          'sign that something is wrong.',
    ),
    (
      heading: 'What olf does in the meantime',
      body:
          'Keep logging as normal. olf keeps your history intact and waits '
          'until there are enough post-change cycles to go on before it '
          'shows a forecast again. The note also clears on its own after a '
          'while, and you can dismiss it early from the prediction card.',
    ),
  ],
  findCareLine:
      'If bleeding is very heavy, does not settle, or you are concerned '
      'about how your cycle has changed, contact your doctor, nurse, or a '
      'local health service.',
);
