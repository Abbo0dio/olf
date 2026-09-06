import 'package:olf_core/olf_core.dart';

/// Bundled, non-clinical support text shown alongside postpartum mode (p7.1).
///
/// Kept as data (not inline in the widget) so a content test can assert the
/// required lines are present and so the copy sweep has one place to look.
/// Tone: plain, gentle, never prescriptive. No external links that phone home —
/// any address is plain text the user copies. Reviewed against
/// `requirements.md` §6 and the p4.3 sensitive-copy discipline.
class SupportResources {
  const SupportResources({
    required this.title,
    required this.intro,
    required this.sections,
    required this.findCareLine,
  });

  final String title;
  final String intro;
  final List<({String heading, String body})> sections;

  /// The line pointing to real care — always shown, always last before the
  /// disclaimer.
  final String findCareLine;

  /// The fixed not-a-medical-device line every mode screen carries (§6).
  static const String notMedicalDeviceLine =
      'olf is not a medical device. Nothing here is medical advice or a '
      'diagnosis.';
}

SupportResources supportResourcesFor(PregnancyEndKind kind) => switch (kind) {
  PregnancyEndKind.loss => const SupportResources(
    title: 'After a loss',
    intro:
        'There is no single way this feels, and no timeline you have to keep '
        'to. This is a short, plain list of things that may help — take what '
        'is useful and leave the rest.',
    sections: [
      (
        heading: 'Your body',
        body:
            'Bleeding and cramping can last days to a few weeks. A period '
            'usually returns within one to two months, but it can take '
            'longer, and the first few cycles are often irregular. olf will '
            'wait for you to log a period rather than guessing.',
      ),
      (
        heading: 'Your feelings',
        body:
            'Grief, relief, numbness, anger — any of these, in any order, is '
            'normal. You do not need a reason to find it hard, and you do not '
            'have to be "over it" by any date.',
      ),
      (
        heading: 'People to lean on',
        body:
            'A friend, a partner, a peer-support line, or a counsellor can '
            'all help. You get to choose who you tell and how much.',
      ),
    ],
    findCareLine:
        'If you have heavy bleeding, fever, severe pain, or you are worried '
        'about how you are coping, contact your doctor, midwife, or a local '
        'health service.',
  ),
  PregnancyEndKind.birth => const SupportResources(
    title: 'After a birth',
    intro:
        'The weeks after a birth are a big adjustment. This is a short, plain '
        'list of things that may help — take what is useful and leave the '
        'rest.',
    sections: [
      (
        heading: 'Your cycle',
        body:
            'Periods can take anywhere from a couple of months to over a year '
            'to return, especially while chest- or breastfeeding. The first '
            'few cycles are often longer or more variable than before. olf '
            'tracks them coming back and will not push a prediction until '
            'there is enough to go on.',
      ),
      (
        heading: 'Rest and recovery',
        body:
            'Healing takes time whether the birth was vaginal or caesarean. '
            'Sleep when you can, accept help, and let the housework slide.',
      ),
      (
        heading: 'Your mood',
        body:
            'Feeling up and down in the first couple of weeks is common. If '
            'low mood, anxiety, or feeling disconnected lasts longer than '
            'that or gets in the way of daily life, it is worth talking to '
            'someone — this is common and treatable.',
      ),
    ],
    findCareLine:
        'For heavy bleeding, fever, severe pain, or if your mood is not '
        'lifting, contact your doctor, midwife, or health visitor. Ask about '
        'a postnatal check for yourself, not just the baby.',
  ),
};
