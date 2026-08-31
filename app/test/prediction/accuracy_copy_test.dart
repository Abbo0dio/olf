import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/accuracy_format.dart';

/// The prediction-accuracy screen (p3.5) shows the user *their* number. It must
/// not editorialise about it (non-alarming) and must not make an accuracy claim
/// of its own (no marketing) — that is the whole point of §6 (substantiable
/// claims). It must also be explicit that the numbers stay on the device.
void main() {
  final userFacing = <String>[
    accuracySettingsTitle,
    accuracySettingsSubtitle,
    accuracyScreenTitle,
    accuracyIntro,
    accuracyPrivacyNote,
    accuracyThinHistory,
    accuracyWorkingLabel,
    accuracyErrorLabel,
    accuracyTypicalMissLabel,
    accuracyTypicalMissHint,
    accuracyMedianMissLabel,
    accuracyMedianMissHint,
    accuracyInRangeLabel,
    accuracyTrendLabel,
    accuracySampleSize(12),
    accuracyDays(2),
    accuracyPercent(0.82),
  ];

  test('nothing alarming or judgemental about the user’s result', () {
    final banned = RegExp(
      r'\b(wrong|bad|poor|terrible|awful|useless|unreliable|inaccurate|'
      r'failed|failure|broken|worthless|disappointing)\b',
      caseSensitive: false,
    );
    for (final s in userFacing) {
      expect(
        banned.hasMatch(s),
        isFalse,
        reason: 'alarming/judgemental wording in: "$s"',
      );
    }
  });

  test('the screen makes no accuracy claim of its own', () {
    final marketing = RegExp(
      r'\b(best|most\s+accurate|highly\s+accurate|industry|award|'
      r'proven|guarantee[ds]?|#1|number\s+one|world[- ]class|unmatched|'
      r'clinically)\b',
      caseSensitive: false,
    );
    for (final s in userFacing) {
      expect(
        marketing.hasMatch(s),
        isFalse,
        reason: 'marketing-style accuracy claim in: "$s"',
      );
    }
  });

  test('the privacy note names the device and says nothing is sent', () {
    expect(accuracyPrivacyNote.toLowerCase(), contains('this device'));
    expect(
      RegExp(
        r'nothing is sent|stays? on (this|your) device|never leaves?',
        caseSensitive: false,
      ).hasMatch(accuracyPrivacyNote),
      isTrue,
    );
  });

  test('every metric is shown with its sample size', () {
    expect(accuracySampleSize(1), 'Checked against 1 past period');
    expect(accuracySampleSize(9), 'Checked against 9 past periods');
  });

  test('a null figure renders as an em dash, never a zero', () {
    expect(accuracyDays(null), '—');
    expect(accuracyPercent(null), '—');
  });
}
