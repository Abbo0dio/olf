import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('synthetic histories are deterministic', () {
    for (final make in <SyntheticHistory Function({int seed})>[
      ({int seed = 42}) => SyntheticHistories.regular(seed: seed),
      ({int seed = 42}) => SyntheticHistories.irregular(seed: seed),
      ({int seed = 42}) => SyntheticHistories.pcos(seed: seed),
      ({int seed = 42}) => SyntheticHistories.perimenopause(seed: seed),
      ({int seed = 42}) => SyntheticHistories.postpartum(seed: seed),
    ]) {
      final label = make(seed: 1).label;

      test('$label: same seed → identical history', () {
        final a = make(seed: 7);
        final b = make(seed: 7);
        expect(a.periodStarts, orderedEquals(b.periodStarts));
        expect(a.ovulationByStart, equals(b.ovulationByStart));
      });

      test('$label: different seed → different history', () {
        final a = make(seed: 7);
        final b = make(seed: 8);
        expect(a.periodStarts, isNot(orderedEquals(b.periodStarts)));
      });

      test('$label: well-formed (ascending, plausible lengths)', () {
        final h = make(seed: 3);
        expect(h.periodStarts.length, h.completedCycleCount + 1);
        for (var i = 1; i < h.periodStarts.length; i++) {
          final len = daysBetween(h.periodStarts[i - 1], h.periodStarts[i]);
          expect(len, inInclusiveRange(15, 120));
        }
        // one ovulation truth per completed cycle, inside its span
        expect(h.ovulationByStart.length, h.completedCycleCount);
        for (var i = 0; i < h.periodStarts.length - 1; i++) {
          final ov = h.ovulationByStart[h.periodStarts[i]]!;
          expect(ov.isAfter(h.periodStarts[i]), isTrue);
          expect(ov.isBefore(h.periodStarts[i + 1]), isTrue);
        }
      });
    }

    test('cyclesNewestFirst matches deriveCycles semantics (newest first)', () {
      final h = SyntheticHistories.regular(seed: 5, cycles: 4);
      final cycles = h.cyclesNewestFirst();
      expect(cycles.length, 5);
      expect(cycles.first.isCurrent, isTrue);
      expect(cycles.last.isCurrent, isFalse);
      expect(cycles.first.periodStart, h.periodStarts.last);
      expect(cycles.last.periodStart, h.periodStarts.first);
    });

    test('profiles differ from each other at a fixed seed', () {
      final all = SyntheticHistories.all(seed: 99);
      final signatures = {
        for (final h in all) h.label: h.periodStarts.toString(),
      };
      expect(signatures.values.toSet().length, all.length);
    });
  });
}
