import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// p3.2, §9(1): when the user fixes a mis-logged date the forecast must
/// **visibly** respond — the top complaint about incumbents is that corrections
/// do nothing. [AdaptivePredictor] (v2) should move clearly more than
/// [RobustPredictor] (v1), while the move stays bounded and does not, on
/// average, make accuracy worse.
void main() {
  const v1 = RobustPredictor();
  const v2 = AdaptivePredictor();
  final seeds = List<int>.generate(20, (i) => i + 1);
  const mislog = 3;
  const profiles = [
    'regular',
    'irregular',
    'pcos',
    'perimenopause',
    'postpartum',
  ];

  List<SyntheticHistory> setsFor(int seed) => [
    SyntheticHistories.regular(seed: seed),
    SyntheticHistories.irregular(seed: seed),
    SyntheticHistories.pcos(seed: seed),
    SyntheticHistories.perimenopause(seed: seed),
    SyntheticHistories.postpartum(seed: seed),
  ];

  ({double effect, double gain, List<int> allEffects}) summarise(
    int i,
    Predictor p,
  ) {
    var effect = 0.0;
    var gain = 0.0;
    var n = 0;
    final all = <int>[];
    for (final seed in seeds) {
      final run = runCorrectionResponseOn(
        setsFor(seed)[i],
        predictor: p,
        mislogOffsetDays: mislog,
      );
      if (run.meanVisibleEffectDays == null) continue;
      effect += run.meanVisibleEffectDays!;
      gain += run.meanCorrectionGainDays!;
      n++;
      for (final pt in run.scored) {
        all.add(pt.visibleEffectDays!);
      }
    }
    return (effect: effect / n, gain: gain / n, allEffects: all);
  }

  test('v2 responds to a correction clearly more than v1 does', () {
    for (final label in ['irregular', 'pcos', 'perimenopause', 'postpartum']) {
      final i = profiles.indexOf(label);
      final a = summarise(i, v1);
      final b = summarise(i, v2);
      expect(
        a.effect,
        lessThan(1.0),
        reason: '$label: v1 barely moves on a correction (${a.effect})',
      );
      expect(
        b.effect,
        greaterThan(a.effect * 1.4),
        reason: '$label: v2 effect ${b.effect} vs v1 ${a.effect}',
      );
    }
  });

  test('correcting a date does not make v2 less accurate on average', () {
    for (var i = 0; i < profiles.length; i++) {
      final b = summarise(i, v2);
      expect(
        b.gain,
        greaterThanOrEqualTo(-0.3),
        reason: '${profiles[i]}: mean correction gain ${b.gain}',
      );
    }
  });

  test('v2 response is bounded — no over-reaction to a small mis-log', () {
    for (var i = 0; i < profiles.length; i++) {
      final effects = summarise(i, v2).allEffects..sort();
      final p90 = effects[(effects.length * 0.90).floor()];
      expect(
        p90,
        lessThanOrEqualTo(mislog + 3),
        reason:
            '${profiles[i]}: 90th-pct visible effect $p90 d '
            '(rare larger tail is p3.4 territory)',
      );
    }
  });
}
