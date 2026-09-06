import 'dart:typed_data';

import 'package:olf_core/olf_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../cycle/cycle_format.dart';
import '../period/period_format.dart';
import '../prediction/prediction_format.dart';

/// Render a [ClinicalReport] to a single, print-friendly, black-on-white PDF
/// (p6.5). Pure bytes-in / bytes-out — no file system, no network, no `pdf`
/// companion (`printing` is deliberately not a dependency: the file is shared
/// through the SAF seam, not sent to the OS print dialog).
///
/// The document uses the built-in Helvetica core font (no bundled asset, no APK
/// size hit); every string is folded to Latin-1 first via [_ascii].
///
/// [compress] leaves `pdf`'s default zlib stream compression on; a test passes
/// `false` so it can assert the disclaimer text is present in the content
/// stream.
Future<Uint8List> buildReportPdf(
  ClinicalReport report, {
  TemperatureUnit unit = TemperatureUnit.celsius,
  bool compress = true,
}) {
  final doc = pw.Document(
    compress: compress,
    title: 'olf cycle report',
    creator: 'olf',
  );

  final base = pw.TextStyle(fontSize: 10, color: PdfColors.black);
  final h1 = base.copyWith(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final h2 = base.copyWith(fontSize: 12, fontWeight: pw.FontWeight.bold);
  final small = base.copyWith(fontSize: 8, color: PdfColors.grey700);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: _text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          small,
        ),
      ),
      build: (context) => [
        _text('Cycle history report', h1),
        pw.SizedBox(height: 4),
        _text('Generated ${formatDay(report.generatedOn)}', base),
        _text(
          'Covers ${formatDay(report.includedRange.start)} to '
          '${formatDay(report.includedRange.end)}',
          base,
        ),
        if (report.retentionExcludedEarlierData)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: _text(
              'Note: entries before ${formatDay(report.includedRange.start)} '
              'were automatically deleted by this device\'s retention setting '
              'and are not included, even though an earlier start date '
              '(${formatDay(report.requestedRange.start)}) was requested.',
              base.copyWith(fontStyle: pw.FontStyle.italic),
            ),
          ),
        pw.SizedBox(height: 16),

        _sectionTitle('Summary', h2),
        _summary(report.summary, base),
        pw.SizedBox(height: 6),
        _prediction(report, base, small),
        pw.SizedBox(height: 16),

        _sectionTitle('Cycles', h2),
        _cycleTable(report.cycles, base),
        pw.SizedBox(height: 16),

        _sectionTitle('Symptoms', h2),
        _symptomTable(report.symptomFrequency, base),
        pw.SizedBox(height: 16),

        _sectionTitle('Basal body temperature', h2),
        _temperature(report.temperatureSeries, unit, base, small),

        if (report.pregnancyEvents.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _sectionTitle('Pregnancy loss & birth', h2),
          _pregnancyList(report.pregnancyEvents, base),
        ],

        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColors.grey500),
        _text(report.disclaimer, small),
      ],
    ),
  );

  return doc.save();
}

/// Fold the typographic characters olf's own copy and user-entered names can
/// carry down to Latin-1 so the Helvetica core font can draw them.
///
// SHORTCUT: ceiling — a symptom name in a non-Latin script still can't be
// drawn (its glyphs drop, with a `pdf` warning). Upgrade path: bundle a compact
// Unicode TTF (e.g. Noto Sans) as an asset and pass it as the document font.
String _ascii(String s) => s
    .replaceAll('–', '-') // en dash
    .replaceAll('—', '-') // em dash
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...')
    .replaceAll(' ', ' ');

pw.Widget _text(String s, pw.TextStyle style) =>
    pw.Text(_ascii(s), style: style);

pw.Widget _sectionTitle(String text, pw.TextStyle style) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: _text(text, style),
);

String _days(int? n) => n == null ? '-' : '$n days';

pw.Widget _summary(ReportSummary s, pw.TextStyle base) {
  if (s.isEmpty) {
    return _text('Not enough logged history to summarise.', base);
  }
  final rows = <List<String>>[
    ['Completed cycles', '${s.cycleCount}'],
    ['Cycle length (mean)', _days(s.meanCycleLength)],
    [
      'Cycle length (range)',
      s.shortestCycleLength == null
          ? '-'
          : '${s.shortestCycleLength} to ${s.longestCycleLength} days',
    ],
    ['Cycle length variability', _days(s.cycleLengthVariability)],
    ['Regularity', s.regularity.label],
    ['Periods with an end date', '${s.periodCount}'],
    ['Period length (mean)', _days(s.meanPeriodLength)],
    [
      'Period length (range)',
      s.shortestPeriodLength == null
          ? '-'
          : '${s.shortestPeriodLength} to ${s.longestPeriodLength} days',
    ],
    if (s.hasLikelyGap)
      [
        'Note',
        'A long gap in the history looks like a missed entry; it is left out '
            'of the figures above.',
      ],
  ];
  return _kvTable(rows, base);
}

pw.Widget _prediction(
  ClinicalReport report,
  pw.TextStyle base,
  pw.TextStyle small,
) {
  final p = report.prediction;
  if (p == null) {
    return _text(
      'Next-period estimate: not shown - the logged history is still too '
      'short for a meaningful estimate.',
      base,
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _text(
        'Next period estimated ${formatDateRange(p.nextPeriod)} '
        '(most likely ${formatDay(p.nextPeriodExpected)}). '
        '${confidenceLabel(p.confidence)}, from ${p.basedOnCycles} '
        '${p.basedOnCycles == 1 ? 'cycle' : 'cycles'}.',
        base,
      ),
      pw.SizedBox(height: 2),
      _text(report.predictionCaveat, small),
    ],
  );
}

pw.Widget _cycleTable(List<ReportCycle> cycles, pw.TextStyle base) {
  if (cycles.isEmpty) {
    return _text('No cycles logged in this range.', base);
  }
  final data = <List<String>>[
    for (final c in cycles)
      [
        formatDay(c.start),
        c.end == null ? '-' : formatDay(c.end!),
        c.lengthInDays == null ? 'current' : '${c.lengthInDays}',
        c.periodLengthInDays == null ? '-' : '${c.periodLengthInDays}',
        [
          if (c.isPregnancyGap) 'pregnancy loss / birth',
          if (c.isLikelyGap) 'likely missed entry',
        ].join('; '),
      ],
  ];
  return pw.TableHelper.fromTextArray(
    headers: const [
      'Start',
      'Period end',
      'Cycle length',
      'Period length',
      'Notes',
    ],
    data: [
      for (final row in data) [for (final cell in row) _ascii(cell)],
    ],
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headerStyle: base.copyWith(fontWeight: pw.FontWeight.bold),
    cellStyle: base,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _symptomTable(List<SymptomFrequency> rows, pw.TextStyle base) {
  if (rows.isEmpty) {
    return _text('No symptoms logged in this range.', base);
  }
  return pw.TableHelper.fromTextArray(
    headers: const ['Symptom', 'Days logged'],
    data: [
      for (final r in rows) [_ascii(r.name), '${r.dayCount}'],
    ],
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    headerStyle: base.copyWith(fontWeight: pw.FontWeight.bold),
    cellStyle: base,
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _pregnancyList(List<ReportPregnancyEvent> events, pw.TextStyle base) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final e in events)
        pw.Bullet(
          text: _ascii(
            '${formatDay(e.date)} - '
            '${e.kind == PregnancyEndKind.loss ? 'pregnancy loss' : 'birth'}',
          ),
          style: base,
        ),
    ],
  );
}

pw.Widget _temperature(
  List<TemperaturePoint> series,
  TemperatureUnit unit,
  pw.TextStyle base,
  pw.TextStyle small,
) {
  if (series.length < 2) {
    return _text(
      series.isEmpty
          ? 'No basal body temperature readings logged in this range.'
          : 'Only one basal body temperature reading logged in this range '
                '(${_temp(series.single.celsius, unit)}).',
      base,
    );
  }

  final values = series
      .map((p) => convertFromCelsius(p.celsius, unit))
      .toList();
  final lo = values.reduce((a, b) => a < b ? a : b);
  final hi = values.reduce((a, b) => a > b ? a : b);
  final span = (hi - lo).abs() < 0.01 ? 1.0 : hi - lo;
  final sym = unit.symbol;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _text(
        '${series.length} readings, '
        '${_temp(series.first.celsius, unit)} to '
        '${_temp(series.last.celsius, unit)} '
        '(${formatDay(series.first.date)} to ${formatDay(series.last.date)}).',
        base,
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        height: 140,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.CustomPaint(
          size: const PdfPoint(515, 140),
          painter: (canvas, size) {
            const pad = 6.0;
            final w = size.x - pad * 2;
            final h = size.y - pad * 2;
            canvas
              ..setStrokeColor(PdfColors.black)
              ..setLineWidth(1);
            for (var i = 0; i < values.length; i++) {
              final x =
                  pad +
                  (values.length == 1 ? 0.0 : w * i / (values.length - 1));
              final y = pad + h * (values[i] - lo) / span;
              i == 0 ? canvas.moveTo(x, y) : canvas.lineTo(x, y);
            }
            canvas.strokePath();
          },
        ),
      ),
      pw.SizedBox(height: 2),
      _text(
        'Y axis: ${lo.toStringAsFixed(2)}$sym (bottom) to '
        '${hi.toStringAsFixed(2)}$sym (top). X axis: time, earliest on the left.',
        small,
      ),
    ],
  );
}

String _temp(double celsius, TemperatureUnit unit) =>
    '${convertFromCelsius(celsius, unit).toStringAsFixed(2)}${unit.symbol}';

pw.Widget _kvTable(List<List<String>> rows, pw.TextStyle base) {
  return pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
    children: [
      for (final r in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: _text(r[0], base),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: _text(r[1], base),
            ),
          ],
        ),
    ],
  );
}
