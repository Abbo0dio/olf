/// Bundled week-by-week development notes for pregnancy mode (p7.2a).
///
/// One short, plain line per completed gestational week, 0 through
/// [kMaxPregnancyWeek]. Deliberately **not** a medical timeline: the copy is
/// non-clinical and non-alarming, names no measurements as targets, gives no
/// instructions, and carries no links. The not-a-medical-device line lives on
/// the screen that shows these, not in every entry.
///
/// Reviewed against the p4.3 sensitive-copy discipline; the p1.9
/// inclusive-language lint scans this file automatically (it covers `core/lib`),
/// and `pregnancy_week_notes_test.dart` locks the tone and the entry count.
library;

import 'gestational_age.dart';

/// Index = completed gestational week. Length is [kMaxPregnancyWeek] + 1.
const List<String> kPregnancyWeekNotes = <String>[
  // 0
  'Counting begins on the first day of your last period — about two weeks '
      'before conception.',
  // 1
  'Still very early. The body is getting ready to release an egg toward the '
      'end of this week.',
  // 2
  'Conception usually happens around the end of this week.',
  // 3
  'A fertilised egg is settling into the lining of the uterus.',
  // 4
  'Around now a period is often missed, and early tests may start to read '
      'positive.',
  // 5
  'The early structures of the brain, spine and heart are taking shape.',
  // 6
  'The embryo is about the size of a lentil. Early tiredness or nausea is '
      'common.',
  // 7
  'Tiny buds that become the arms and legs are appearing.',
  // 8
  'Fingers and toes are starting to form. Many first prenatal visits happen '
      'around now.',
  // 9
  'Now about the size of a grape. The heart has settled into a steady rhythm.',
  // 10
  'The main organs are formed and will keep maturing for the rest of '
      'pregnancy.',
  // 11
  'The head is large compared with the body for now, and bones are beginning '
      'to harden.',
  // 12
  'Around the size of a plum. For many people nausea starts to ease over the '
      'coming weeks.',
  // 13
  'End of the first trimester. Many people begin sharing their news around '
      'this time.',
  // 14
  'Second trimester begins. Energy often picks up during this stretch.',
  // 15
  'The baby can make small movements, though they are far too light to feel '
      'yet.',
  // 16
  'Around the size of an avocado. Some people feel the first faint flutters '
      'over the next few weeks.',
  // 17
  'The baby is putting on a little fat and practising swallowing.',
  // 18
  'A mid-pregnancy scan is often offered around now.',
  // 19
  'Hearing is developing, and the baby may begin to pick up on sounds.',
  // 20
  'Roughly the halfway point. Movements usually become clearer from here.',
  // 21
  'The baby has periods of sleep and of activity through the day and night.',
  // 22
  'Around the size of a small papaya. Eyebrows and eyelashes are forming.',
  // 23
  "The baby's face is fully formed, just smaller and thinner than at birth.",
  // 24
  'The lungs are building the fine branching structures they will need later.',
  // 25
  'The baby is gaining weight steadily and the skin is filling out.',
  // 26
  'The eyes begin to open around this time.',
  // 27
  'Last week of the second trimester. Kicks and rolls often feel stronger now.',
  // 28
  'Third trimester begins. Prenatal visits usually become more frequent.',
  // 29
  'The bones are fully formed and continue to harden, taking on calcium.',
  // 30
  'Around the size of a large cabbage. The baby fills more of the available '
      'space.',
  // 31
  'The baby can turn its head and is putting on fat for warmth after birth.',
  // 32
  'Many babies move into a head-down position over the coming weeks.',
  // 33
  "The baby's skull stays soft and flexible to make the journey through birth "
      'easier.',
  // 34
  'The central nervous system and lungs are maturing well.',
  // 35
  'Most development is complete. These weeks are mainly about growing.',
  // 36
  'The baby is likely head-down now. Check-ups often become weekly around '
      'here.',
  // 37
  'Considered early term. Everyday preparations tend to wrap up around now.',
  // 38
  'The baby keeps adding fat, which helps with temperature control after '
      'birth.',
  // 39
  'Full term. The baby is ready to be born whenever labour begins.',
  // 40
  'The estimated due date is around now. Many pregnancies continue a little '
      'past it.',
  // 41
  'Going a week or so past the due date is common. Extra check-ups are usually '
      'offered.',
  // 42
  'Care providers usually talk through the options if pregnancy continues to '
      'this point.',
];

/// The note for [completedWeeks], clamped to the range [kPregnancyWeekNotes]
/// covers so a post-dates pregnancy still gets its closest line.
String pregnancyWeekNote(int completedWeeks) =>
    kPregnancyWeekNotes[completedWeeks.clamp(0, kMaxPregnancyWeek)];
