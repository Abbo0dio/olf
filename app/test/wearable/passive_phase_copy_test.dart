import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/prediction/prediction_format.dart';
import 'package:olf_core/olf_core.dart';

/// p8.5 — the passive temperature-shift note must describe a **pattern**, never
/// deliver a verdict (§6, §9(12)): no "you did not ovulate", no fertility /
/// conception / pregnancy claim, no alarm, no imperative scolding. It must
/// always frame itself as a correctable estimate.
void main() {
  PassivePhaseEstimate est(PassiveConfidence c) => PassivePhaseEstimate(
    read: PassivePhaseRead.ovulationLikelyPassed,
    estimatedOvulation: DateTime(2026, 3, 14),
    confidence: c,
    trackUsed: PassiveSignalTrack.sleepingWrist,
    postShiftReadingCount: 5,
    riseCelsius: 0.33,
  );

  final all = [
    for (final c in PassiveConfidence.values) passivePhaseNote(est(c)),
    passivePhaseNoteRedacted,
  ];

  test('no diagnosis / fertility-verdict phrasing', () {
    final banned = <RegExp>[
      RegExp(r'did ?n.?t ovulate', caseSensitive: false),
      RegExp(r'\bno ovulation\b', caseSensitive: false),
      RegExp(r'anovulat', caseSensitive: false),
      RegExp(r'pregnan', caseSensitive: false),
      RegExp(r'concei', caseSensitive: false),
      RegExp(r'\binfertile\b', caseSensitive: false),
      RegExp(r'\bfertile\b', caseSensitive: false),
      RegExp(r"\byou'?re safe\b", caseSensitive: false),
      RegExp(r'\bcan.?t get pregnant\b', caseSensitive: false),
      RegExp(r'diagnos', caseSensitive: false),
      RegExp(r'\bdisorder\b', caseSensitive: false),
    ];
    for (final s in all) {
      for (final re in banned) {
        expect(re.hasMatch(s), isFalse, reason: '"$s" matched $re');
      }
    }
  });

  test('no alarm / imperative scolding', () {
    final banned = <RegExp>[
      RegExp(r'\byou must\b', caseSensitive: false),
      RegExp(r'\byou need to\b', caseSensitive: false),
      RegExp(r'\byou should\b', caseSensitive: false),
      RegExp(r'\bmake sure\b', caseSensitive: false),
      RegExp(r'\bwarning\b', caseSensitive: false),
      RegExp(r'\bconcern(ing)?\b', caseSensitive: false),
      RegExp(r'!'),
    ];
    for (final s in all) {
      for (final re in banned) {
        expect(re.hasMatch(s), isFalse, reason: '"$s" matched $re');
      }
    }
  });

  test('every variant frames itself as a correctable estimate', () {
    for (final c in PassiveConfidence.values) {
      final s = passivePhaseNote(est(c));
      expect(s.toLowerCase(), contains('estimate'));
      expect(s.toLowerCase(), contains('logging'));
      // "likely / usually" hedge — never a bare assertion.
      expect(
        RegExp(
          r'\b(usually|likely|suggests?|tends?)\b',
          caseSensitive: false,
        ).hasMatch(s),
        isTrue,
        reason: '"$s" reads as a bare assertion',
      );
    }
  });

  test('the read only ever points one way (past ovulation)', () {
    // The enum itself has no "did not ovulate" value — guard that stays true.
    expect(PassivePhaseRead.values, [PassivePhaseRead.ovulationLikelyPassed]);
  });
}
