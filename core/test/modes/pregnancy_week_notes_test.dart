import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('covers every week from 0 to kMaxPregnancyWeek', () {
    expect(kPregnancyWeekNotes, hasLength(kMaxPregnancyWeek + 1));
  });

  test('every entry is a non-empty, single-sentence-ish line', () {
    for (var week = 0; week < kPregnancyWeekNotes.length; week++) {
      final note = kPregnancyWeekNotes[week];
      expect(note.trim(), isNotEmpty, reason: 'week $week is empty');
      expect(
        note.length,
        lessThanOrEqualTo(160),
        reason: 'week $week is ${note.length} chars: "$note"',
      );
      expect(note.trim(), endsWith('.'), reason: 'week $week: "$note"');
    }
  });

  test('the tone stays calm — no directives, no alarm, no shouting', () {
    // p4.3 sensitive-copy discipline: descriptive, never instructive or scary.
    const bannedSubstrings = <String>[
      'should',
      'must ',
      'need to',
      'make sure',
      'have to',
      'risk',
      'danger',
      'emergency',
      'abnormal',
      'warning',
      'miscarriage',
      ' loss',
      'complication',
      'diagnos',
      'you will need',
    ];
    for (var week = 0; week < kPregnancyWeekNotes.length; week++) {
      final lower = kPregnancyWeekNotes[week].toLowerCase();
      for (final bad in bannedSubstrings) {
        expect(
          lower.contains(bad),
          isFalse,
          reason: 'week $week leaks "$bad": "${kPregnancyWeekNotes[week]}"',
        );
      }
      expect(kPregnancyWeekNotes[week], isNot(contains('!')));
      expect(kPregnancyWeekNotes[week], isNot(contains('?')));
      expect(
        kPregnancyWeekNotes[week],
        isNot(contains('http')),
        reason: 'week $week carries a link',
      );
    }
  });

  group('pregnancyWeekNote', () {
    test('returns the entry for an in-range week', () {
      expect(pregnancyWeekNote(0), kPregnancyWeekNotes.first);
      expect(pregnancyWeekNote(20), kPregnancyWeekNotes[20]);
      expect(pregnancyWeekNote(kMaxPregnancyWeek), kPregnancyWeekNotes.last);
    });

    test('clamps below 0 and above the last covered week', () {
      expect(pregnancyWeekNote(-3), kPregnancyWeekNotes.first);
      expect(pregnancyWeekNote(99), kPregnancyWeekNotes.last);
    });
  });
}
