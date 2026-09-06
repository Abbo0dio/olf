import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../backup/backup_providers.dart';
import '../bbt/bbt_providers.dart';
import '../pregnancy/pregnancy_providers.dart';
import '../period/period_providers.dart';
import '../prediction/prediction_providers.dart';
import '../retention/retention_providers.dart';
import '../symptom/symptom_providers.dart';
import 'report_pdf.dart';

/// The spans offered by the doctor-report range picker.
enum ReportRange {
  last3Months,
  last6Months,
  last12Months,
  all;

  String get label => switch (this) {
    ReportRange.last3Months => 'Last 3 months',
    ReportRange.last6Months => 'Last 6 months',
    ReportRange.last12Months => 'Last 12 months',
    ReportRange.all => 'All history',
  };

  /// The requested start date for [today]. [earliestData] is the oldest logged
  /// entry of any kind, used only by [ReportRange.all] (which otherwise has no
  /// natural lower bound); it falls back to [today] when there is no data.
  DateTime startDate(DateTime today, {DateTime? earliestData}) {
    final t = DateTime(today.year, today.month, today.day);
    return switch (this) {
      ReportRange.last3Months => DateTime(t.year, t.month - 3, t.day),
      ReportRange.last6Months => DateTime(t.year, t.month - 6, t.day),
      ReportRange.last12Months => DateTime(t.year - 1, t.month, t.day),
      ReportRange.all => earliestData ?? t,
    };
  }
}

/// The report model for [range], assembled from the live repositories. Rebuilds
/// when any underlying data changes, so the on-screen preview stays honest.
final reportModelProvider = FutureProvider.autoDispose
    .family<ClinicalReport, ReportRange>((ref, range) async {
      final periods = await ref.watch(periodsProvider.future);
      final events = await ref.watch(pregnancyEventsProvider.future);
      final entries = await ref.watch(symptomEntriesProvider.future);
      final types = await ref.watch(allSymptomTypesProvider.future);
      final temps = await ref.watch(bbtRepositoryProvider).allEntries();
      final window = await ref.watch(retentionWindowProvider.future);
      final predictor = ref.watch(predictorProvider);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cycles = deriveCycles(periods, pregnancyEvents: events);

      final earliest = _earliestData(
        periods: periods,
        entries: entries,
        temps: temps,
        events: events,
      );

      return buildClinicalReport(
        generatedOn: today,
        rangeStart: range.startDate(today, earliestData: earliest),
        rangeEnd: today,
        retentionCutoff: window.cutoff(now),
        periods: periods,
        pregnancyEvents: events,
        symptomEntries: entries,
        symptomNames: {for (final t in types) t.id: t.name},
        temperatures: temps,
        prediction: predictor.predict(cycles: cycles, today: today),
      );
    });

DateTime? _earliestData({
  required List<Period> periods,
  required List<DailySymptomEntry> entries,
  required List<BbtEntry> temps,
  required List<PregnancyEvent> events,
}) {
  final candidates = <DateTime>[
    for (final p in periods) dateOnly(p.startDate),
    for (final e in entries) dateOnly(e.date),
    for (final t in temps) dateOnly(t.date),
    for (final e in events) dateOnly(e.date),
  ];
  if (candidates.isEmpty) return null;
  return candidates.reduce((a, b) => a.isBefore(b) ? a : b);
}

/// Outcome of a "Generate report" action.
sealed class ReportExportResult {
  const ReportExportResult();
}

/// The PDF was written to [path].
class ReportExportSaved extends ReportExportResult {
  const ReportExportSaved(this.path);
  final String path;
}

/// The user dismissed the save dialog.
class ReportExportCancelled extends ReportExportResult {
  const ReportExportCancelled();
}

/// The report carried nothing to export.
class ReportExportNoData extends ReportExportResult {
  const ReportExportNoData();
}

final clinicalReportControllerProvider = Provider<ClinicalReportController>(
  ClinicalReportController.new,
);

/// Drives the one user action: purge past the retention window (p2.3), build
/// the pure [ClinicalReport], render it to a PDF, and hand the bytes to the
/// SAF seam. Everything happens on-device.
class ClinicalReportController {
  ClinicalReportController(this._ref);

  final Ref _ref;

  Future<ReportExportResult> generate(ReportRange range) async {
    // Purge-before-export (matches the p1.10 backup flow): anything past the
    // retention window is deleted before the snapshot is taken, so it can never
    // reach the file.
    await _ref.read(retentionControllerProvider).sweepNow();
    _ref.invalidate(reportModelProvider(range));

    final report = await _ref.read(reportModelProvider(range).future);
    if (!report.hasAnyData) return const ReportExportNoData();

    final unit =
        _ref.read(temperatureUnitProvider).valueOrNull ??
        TemperatureUnit.celsius;
    final Uint8List bytes = await buildReportPdf(report, unit: unit);

    final path = await _ref
        .read(backupFileGatewayProvider)
        .saveFile(
          bytes,
          suggestedName: _fileName(report.generatedOn),
          dialogTitle: 'Save the report',
        );
    return path == null
        ? const ReportExportCancelled()
        : ReportExportSaved(path);
  }

  /// `olf-report-YYYY-MM-DD.pdf` — a neutral name, no identifier (§3).
  static String _fileName(DateTime day) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'olf-report-${day.year}-${two(day.month)}-${two(day.day)}.pdf';
  }
}
