import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  CyclePrediction pred({
    required DateTime expected,
    required int halfWidth,
    PredictionConfidence confidence = PredictionConfidence.medium,
  }) {
    final ov = expected.subtract(const Duration(days: 14));
    return CyclePrediction(
      nextPeriod: DateRange(
        expected.subtract(Duration(days: halfWidth)),
        expected.add(Duration(days: halfWidth)),
      ),
      nextPeriodExpected: expected,
      fertileWindow: DateRange(
        ov.subtract(const Duration(days: 5)),
        ov.add(const Duration(days: 1)),
      ),
      confidence: confidence,
      basedOnCycles: 6,
      status: PredictionStatus.upcoming,
      daysPastExpected: null,
    );
  }

  final base = pred(expected: DateTime(2025, 3, 20), halfWidth: 4);

  group('structural diff', () {
    test('expected date moving later is reported with sign and wording', () {
      final d = PredictionDelta.between(
        before: base,
        after: pred(expected: DateTime(2025, 3, 23), halfWidth: 4),
      );
      expect(d.expectedShiftDays, 3);
      expect(d.isMeaningful, isTrue);
      expect(d.reasons.join(' '), contains('moved 3 days later'));
    });

    test('a narrower range is reported as narrowed', () {
      final d = PredictionDelta.between(
        before: base,
        after: pred(expected: DateTime(2025, 3, 20), halfWidth: 2),
      );
      expect(d.rangeWidthChangeDays, -4);
      expect(d.reasons.join(' '), contains('narrowed by 4 days'));
    });

    test('a confidence change is called out both ways', () {
      final up = PredictionDelta.between(
        before: pred(
          expected: DateTime(2025, 3, 20),
          halfWidth: 4,
          confidence: PredictionConfidence.low,
        ),
        after: pred(
          expected: DateTime(2025, 3, 20),
          halfWidth: 4,
          confidence: PredictionConfidence.high,
        ),
      );
      expect(up.reasons.join(' '), contains('went up'));
      expect(up.reasons.join(' '), contains('from low to high'));
    });
  });

  group('a correction is never silently dropped', () {
    test(
      'no movement + followedCorrection → an explicit "no change" reason',
      () {
        final d = PredictionDelta.between(
          before: base,
          after: base,
          context: const PredictionChangeContext(followedCorrection: true),
        );
        expect(d.isMeaningful, isFalse);
        expect(d.reasons, isNotEmpty);
        expect(d.reasons.single, contains('did not need to change'));
        expect(d.reasons.single, startsWith('Your correction was applied'));
      },
    );

    test('no movement + no context → no noise', () {
      final d = PredictionDelta.between(before: base, after: base);
      expect(d.reasons, isEmpty);
    });
  });

  group('appear / withdraw', () {
    test('none → some is an "appeared" delta', () {
      final d = PredictionDelta.between(
        before: null,
        after: base,
        context: const PredictionChangeContext(followedCorrection: true),
      );
      expect(d.appeared, isTrue);
      expect(d.isMeaningful, isTrue);
      expect(d.reasons.single, contains('enough history'));
    });

    test('some → none is a "withdrawn" delta', () {
      final d = PredictionDelta.between(before: base, after: null);
      expect(d.withdrawn, isTrue);
      expect(d.reasons.single, contains('paused'));
    });
  });

  test('cycles-added wording is singular / plural aware', () {
    final one = PredictionDelta.between(
      before: base,
      after: pred(expected: DateTime(2025, 3, 22), halfWidth: 4),
      context: const PredictionChangeContext(cyclesAdded: 1),
    );
    expect(one.reasons.first, 'You logged another cycle.');

    final many = PredictionDelta.between(
      before: base,
      after: pred(expected: DateTime(2025, 3, 22), halfWidth: 4),
      context: const PredictionChangeContext(cyclesAdded: 3),
    );
    expect(many.reasons.first, 'You logged 3 more cycles.');
  });

  test('every reason is gender-neutral and non-alarming', () {
    final samples = <PredictionDelta>[
      PredictionDelta.between(
        before: base,
        after: pred(expected: DateTime(2025, 3, 24), halfWidth: 7),
        context: const PredictionChangeContext(followedCorrection: true),
      ),
      PredictionDelta.between(
        before: base,
        after: pred(
          expected: DateTime(2025, 3, 17),
          halfWidth: 2,
          confidence: PredictionConfidence.low,
        ),
        context: const PredictionChangeContext(cyclesAdded: 2),
      ),
      PredictionDelta.between(before: null, after: base),
      PredictionDelta.between(before: base, after: null),
      PredictionDelta.between(
        before: base,
        after: base,
        context: const PredictionChangeContext(followedCorrection: true),
      ),
    ];
    const banned = {
      'she',
      'her',
      'hers',
      'woman',
      'women',
      'girl',
      'lady',
      'wrong',
      'error',
      'mistake',
      'failed',
      'fault',
      'bad',
    };
    for (final d in samples) {
      for (final line in d.reasons) {
        final words = line
            .toLowerCase()
            .split(RegExp(r"[^a-z]+"))
            .where((w) => w.isNotEmpty);
        for (final w in words) {
          expect(
            banned,
            isNot(contains(w)),
            reason: 'reason line "$line" contains a banned word "$w"',
          );
        }
      }
    }
  });
}
