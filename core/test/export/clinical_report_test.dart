import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start, [DateTime? end]) => Period(
    id: nextId++,
    startDate: start,
    endDate: end,
    createdAt: epoch,
    updatedAt: epoch,
  );

  BbtEntry temp(DateTime date, double celsius) => BbtEntry(
    date: date,
    tempCelsius: celsius,
    source: 'manual',
    createdAt: epoch,
    updatedAt: epoch,
  );

  DailySymptomEntry symptom(DateTime date, int typeId) =>
      DailySymptomEntry(date: date, symptomTypeId: typeId, createdAt: epoch);

  PregnancyEvent pregnancy(DateTime date, PregnancyEndKind kind) =>
      PregnancyEvent(id: nextId++, kind: kind, date: date);

  setUp(() => nextId = 1);

  // Six periods 28–31 days apart: cycle lengths 28, 30, 27, 31, 28.
  List<Period> regularHistory() {
    var d = DateTime(2026, 1, 5);
    final out = <Period>[];
    for (final gap in const [28, 30, 27, 31, 28]) {
      out.add(period(d, d.add(const Duration(days: 4)))); // 5-day period
      d = d.add(Duration(days: gap));
    }
    out.add(period(d, d.add(const Duration(days: 4)))); // current, open
    return out;
  }

  group('buildClinicalReport', () {
    test('is deterministic for a fixed dataset', () {
      final periods = regularHistory();
      ClinicalReport run() => buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1, 9, 30),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: periods,
        pregnancyEvents: const [],
        symptomEntries: [symptom(DateTime(2026, 2, 10), 1)],
        symptomNames: const {1: 'Cramps'},
        temperatures: [temp(DateTime(2026, 2, 10), 36.5)],
        prediction: null,
      );

      final a = run();
      final b = run();
      expect(a.generatedOn, b.generatedOn);
      expect(a.cycles.length, b.cycles.length);
      expect(a.summary.meanCycleLength, b.summary.meanCycleLength);
      expect(a.symptomFrequency.single.name, b.symptomFrequency.single.name);
      expect(a.generatedOn, DateTime(2026, 7, 1)); // time-of-day dropped
    });

    test('cycle table is oldest-first with correct lengths', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: regularHistory(),
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );

      expect(report.cycles, hasLength(6));
      expect(
        report.cycles.map((c) => c.lengthInDays).toList(),
        [28, 30, 27, 31, 28, null], // last cycle still open
      );
      expect(report.cycles.every((c) => c.periodLengthInDays == 5), isTrue);
      final starts = report.cycles.map((c) => c.start).toList();
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i].isAfter(starts[i - 1]), isTrue);
      }
    });

    test('summary maths: mean, range and variability', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: regularHistory(),
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );

      // Completed non-gap cycles: 28, 30, 27, 31, 28  → mean 28.8 → 29.
      expect(report.summary.cycleCount, 5);
      expect(report.summary.meanCycleLength, 29);
      expect(report.summary.shortestCycleLength, 27);
      expect(report.summary.longestCycleLength, 31);
      expect(report.summary.cycleLengthVariability, 4);
      expect(report.summary.periodCount, 6);
      expect(report.summary.meanPeriodLength, 5);
      expect(report.summary.shortestPeriodLength, 5);
      expect(report.summary.longestPeriodLength, 5);
      expect(report.summary.hasLikelyGap, isFalse);
    });

    test('retention cutoff clamps the range and is reported', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        retentionCutoff: DateTime(2026, 4, 1),
        periods: regularHistory(),
        pregnancyEvents: const [],
        symptomEntries: [
          symptom(DateTime(2026, 2, 10), 1), // before cutoff — excluded
          symptom(DateTime(2026, 5, 10), 1), // inside — kept
        ],
        symptomNames: const {1: 'Cramps'},
        temperatures: [
          temp(DateTime(2026, 2, 10), 36.4), // excluded
          temp(DateTime(2026, 5, 10), 36.7), // kept
        ],
        prediction: null,
      );

      expect(report.retentionExcludedEarlierData, isTrue);
      expect(report.includedRange.start, DateTime(2026, 4, 1));
      expect(report.requestedRange.start, DateTime(2026, 1, 1));
      expect(report.temperatureSeries, hasLength(1));
      expect(report.temperatureSeries.single.celsius, 36.7);
      expect(report.symptomFrequency.single.dayCount, 1);
      // Only cycles opening on/after 1 Apr survive.
      expect(
        report.cycles.every((c) => !c.start.isBefore(DateTime(2026, 4, 1))),
        isTrue,
      );
    });

    test('no clamp when retention starts before the requested range', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 3, 1),
        rangeEnd: DateTime(2026, 7, 1),
        retentionCutoff: DateTime(2026, 1, 1),
        periods: regularHistory(),
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );
      expect(report.retentionExcludedEarlierData, isFalse);
      expect(report.includedRange.start, DateTime(2026, 3, 1));
    });

    test('empty history still produces a valid report', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: const [],
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );

      expect(report.cycles, isEmpty);
      expect(report.summary.isEmpty, isTrue);
      expect(report.summary.meanCycleLength, isNull);
      expect(report.summary.cycleLengthVariability, isNull);
      expect(report.hasAnyData, isFalse);
      expect(report.disclaimer, contains('not a medical device'));
    });

    test('carries the fixed disclaimer and prediction caveat', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: const [],
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );
      expect(report.disclaimer, clinicalReportDisclaimer);
      expect(report.predictionCaveat, clinicalReportPredictionCaveat);
      expect(report.predictionCaveat, isNotEmpty);
    });

    test('symptom frequency counts days, most frequent first', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: const [],
        pregnancyEvents: const [],
        symptomEntries: [
          symptom(DateTime(2026, 2, 1), 1),
          symptom(DateTime(2026, 2, 2), 1),
          symptom(DateTime(2026, 2, 3), 1),
          symptom(DateTime(2026, 2, 1), 2),
          symptom(DateTime(2026, 2, 2), 2),
          symptom(DateTime(2026, 2, 1), 9), // archived / unknown name
        ],
        symptomNames: const {1: 'Cramps', 2: 'Headache'},
        temperatures: const [],
        prediction: null,
      );

      expect(
        report.symptomFrequency.map((s) => '${s.name}:${s.dayCount}').toList(),
        ['Cramps:3', 'Headache:2', 'Removed symptom:1'],
      );
    });

    test('temperature series is filtered to range and sorted ascending', () {
      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 2, 1),
        rangeEnd: DateTime(2026, 3, 1),
        periods: const [],
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: [
          temp(DateTime(2026, 2, 20), 36.8),
          temp(DateTime(2026, 1, 15), 36.1), // before range
          temp(DateTime(2026, 2, 5), 36.4),
          temp(DateTime(2026, 4, 1), 36.9), // after range
        ],
        prediction: null,
      );

      expect(report.temperatureSeries.map((p) => p.date).toList(), [
        DateTime(2026, 2, 5),
        DateTime(2026, 2, 20),
      ]);
    });

    test('pregnancy events are filtered, sorted, and flag their cycle', () {
      var d = DateTime(2026, 1, 5);
      final periods = <Period>[period(d, d.add(const Duration(days: 4)))];
      d = d.add(const Duration(days: 90)); // long gap around a loss
      periods.add(period(d, d.add(const Duration(days: 4))));

      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: periods,
        pregnancyEvents: [
          pregnancy(DateTime(2026, 3, 1), PregnancyEndKind.loss),
          pregnancy(
            DateTime(2025, 6, 1),
            PregnancyEndKind.birth,
          ), // out of range
        ],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: null,
      );

      expect(report.pregnancyEvents, hasLength(1));
      expect(report.pregnancyEvents.single.kind, PregnancyEndKind.loss);
      expect(report.cycles.any((c) => c.isPregnancyGap), isTrue);
    });

    test('passes the prediction through untouched', () {
      final prediction = const RobustPredictor().predict(
        cycles: deriveCycles(regularHistory()),
        today: DateTime(2026, 7, 1),
      );
      expect(prediction, isNotNull);

      final report = buildClinicalReport(
        generatedOn: DateTime(2026, 7, 1),
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 7, 1),
        periods: regularHistory(),
        pregnancyEvents: const [],
        symptomEntries: const [],
        symptomNames: const {},
        temperatures: const [],
        prediction: prediction,
      );
      expect(report.prediction, same(prediction));
    });

    test('throws when the range is inverted', () {
      expect(
        () => buildClinicalReport(
          generatedOn: DateTime(2026, 7, 1),
          rangeStart: DateTime(2026, 7, 1),
          rangeEnd: DateTime(2026, 1, 1),
          periods: const [],
          pregnancyEvents: const [],
          symptomEntries: const [],
          symptomNames: const {},
          temperatures: const [],
          prediction: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
