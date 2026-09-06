import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;
  setUp(() => nextId = 1);

  Period period(DateTime start) => Period(
    id: nextId++,
    startDate: start,
    endDate: start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );

  /// `n` back-to-back 28-day cycles (first period on [first]); last is open.
  List<Cycle> cycles28({required DateTime first, required int n}) =>
      deriveCycles([
        for (var i = 0; i < n; i++) period(first.add(Duration(days: 28 * i))),
      ]);

  PainEntry pain(
    DateTime date, {
    SymptomSeverity intensity = SymptomSeverity.moderate,
    bool isFlare = false,
  }) => PainEntry(
    date: date,
    intensity: intensity,
    isFlare: isFlare,
    createdAt: epoch,
    updatedAt: epoch,
  );

  group('painFlareEvents', () {
    test(
      'emits a Pain event for every day and a Flare event for flare days',
      () {
        final events = painFlareEvents([
          pain(DateTime(2026, 1, 5)),
          pain(DateTime(2026, 1, 8), isFlare: true),
        ]);

        expect(events.map((e) => (e.day, e.category)), [
          (DateTime(2026, 1, 5), painEventCategory),
          (DateTime(2026, 1, 8), painEventCategory),
          (DateTime(2026, 1, 8), flareEventCategory),
        ]);
      },
    );

    test('is deterministic and order-preserving', () {
      final entries = [
        pain(DateTime(2026, 2, 1), isFlare: true),
        pain(DateTime(2026, 1, 1)),
      ];
      expect(
        painFlareEvents(entries).map((e) => (e.day, e.category)),
        painFlareEvents(entries).map((e) => (e.day, e.category)),
      );
    });

    test('empty in, empty out', () {
      expect(painFlareEvents(const []), isEmpty);
    });
  });

  group('flare ↔ cycle-phase correlation (via cyclePhaseCorrelations)', () {
    final first = DateTime(2026, 1, 1);
    // 28-day cycle, period days 1–4 →
    //   menstrual d1..d4 · follicular d5..d9 · ovulatory d10..d16 · luteal d17..d28
    DateTime cycleDay(int cycleIndex, int day) =>
        first.add(Duration(days: 28 * cycleIndex + (day - 1)));

    test(
      'flares clustered in the late luteal / menstrual phase name a phase',
      () {
        final cycles = cycles28(first: first, n: 4); // 3 completed + 1 open
        final entries = <PainEntry>[
          for (var c = 0; c < 3; c++) ...[
            pain(cycleDay(c, 24), isFlare: true),
            pain(cycleDay(c, 26), isFlare: true),
            pain(cycleDay(c, 27), isFlare: true),
          ],
        ];

        final byCategory = {
          for (final r in cyclePhaseCorrelations(
            events: painFlareEvents(entries),
            cycles: cycles,
            today: DateTime(2026, 4, 1),
          ))
            r.category: r,
        };

        final flare = byCategory[flareEventCategory]!;
        expect(flare.enoughData, isTrue);
        expect(flare.showsUpMostIn, CyclePhaseKind.luteal);
        // Same days are also counted plainly as pain.
        expect(
          byCategory[painEventCategory]!.showsUpMostIn,
          CyclePhaseKind.luteal,
        );
      },
    );

    test('an even spread of flares reads as no clear pattern', () {
      final cycles = cycles28(first: first, n: 4);
      final entries = <PainEntry>[
        for (var c = 0; c < 3; c++)
          for (final d in const [2, 5, 8, 11, 14, 17, 20, 23, 26])
            pain(cycleDay(c, d), isFlare: true),
      ];

      final flare = cyclePhaseCorrelations(
        events: painFlareEvents(entries),
        cycles: cycles,
        today: DateTime(2026, 4, 1),
      ).firstWhere((r) => r.category == flareEventCategory);

      expect(flare.enoughData, isTrue);
      expect(flare.showsUpMostIn, isNull);
    });

    test('below the data threshold reads as not-enough-data', () {
      final cycles = cycles28(first: first, n: 4);
      final flare = cyclePhaseCorrelations(
        events: painFlareEvents([pain(cycleDay(0, 20), isFlare: true)]),
        cycles: cycles,
        today: DateTime(2026, 4, 1),
      ).firstWhere((r) => r.category == flareEventCategory);

      expect(flare.enoughData, isFalse);
      expect(flare.showsUpMostIn, isNull);
    });

    test('is deterministic for identical input', () {
      final cycles = cycles28(first: first, n: 4);
      final entries = [
        for (var c = 0; c < 3; c++) pain(cycleDay(c, 25), isFlare: true),
      ];
      List<(String, bool, CyclePhaseKind?)> run() => cyclePhaseCorrelations(
        events: painFlareEvents(entries),
        cycles: cycles,
        today: DateTime(2026, 4, 1),
      ).map((r) => (r.category, r.enoughData, r.showsUpMostIn)).toList();

      expect(run(), run());
    });
  });
}
