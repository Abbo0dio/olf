import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/export/report_pdf.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start, DateTime end) => Period(
    id: nextId++,
    startDate: start,
    endDate: end,
    createdAt: epoch,
    updatedAt: epoch,
  );
  BbtEntry temp(DateTime d, double c) => BbtEntry(
    date: d,
    tempCelsius: c,
    source: 'manual',
    createdAt: epoch,
    updatedAt: epoch,
  );
  DailySymptomEntry symptom(DateTime d, int id) =>
      DailySymptomEntry(date: d, symptomTypeId: id, createdAt: epoch);

  ClinicalReport seededReport() {
    var d = DateTime(2026, 1, 5);
    final periods = <Period>[];
    for (final gap in const [28, 30, 27, 31, 29]) {
      periods.add(period(d, d.add(const Duration(days: 4))));
      d = d.add(Duration(days: gap));
    }
    periods.add(period(d, d.add(const Duration(days: 4))));

    final temps = [
      for (var i = 0; i < 20; i++)
        temp(DateTime(2026, 2, 1).add(Duration(days: i)), 36.3 + (i % 5) * 0.1),
    ];
    final symptoms = [
      for (var i = 0; i < 6; i++) symptom(DateTime(2026, 2, 3 + i), 1),
      for (var i = 0; i < 3; i++) symptom(DateTime(2026, 2, 10 + i), 2),
    ];

    return buildClinicalReport(
      generatedOn: DateTime(2026, 7, 1),
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2026, 7, 1),
      periods: periods,
      pregnancyEvents: const [],
      symptomEntries: symptoms,
      symptomNames: const {1: 'Cramps', 2: 'Headache'},
      temperatures: temps,
      prediction: const RobustPredictor().predict(
        cycles: deriveCycles(periods),
        today: DateTime(2026, 7, 1),
      ),
    );
  }

  test('produces a valid, non-trivial PDF', () async {
    final bytes = await buildReportPdf(seededReport());

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      String.fromCharCodes(bytes.skip(bytes.length - 6)),
      contains('%%EOF'),
    );
    expect(bytes.length, greaterThan(3000));
  });

  test(
    'the "not a medical device" disclaimer is in the content stream',
    () async {
      final bytes = await buildReportPdf(seededReport(), compress: false);
      final text = latin1.decode(bytes, allowInvalid: true);

      // Text is emitted as `(literal)` runs, one per wrapped line — join every
      // literal and check the disclaimer's distinctive words survived.
      final literals = RegExp(
        r'\(([^()\\]*)\)',
      ).allMatches(text).map((m) => m.group(1)!).join(' ');
      for (final word in const [
        'olf',
        'not',
        'a',
        'medical',
        'device',
        'clinical',
      ]) {
        expect(
          literals,
          contains(word),
          reason: 'disclaimer word "$word" missing from the PDF content',
        );
      }
    },
  );

  test(
    'an empty report still renders a valid PDF with the disclaimer',
    () async {
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
      final bytes = await buildReportPdf(report, compress: false);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final literals = RegExp(r'\(([^()\\]*)\)')
          .allMatches(latin1.decode(bytes, allowInvalid: true))
          .map((m) => m.group(1)!)
          .join(' ');
      expect(literals, contains('medical'));
    },
  );
}
