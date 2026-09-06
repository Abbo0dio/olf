import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../period/period_format.dart';
import 'report_providers.dart';

/// "Export report for a doctor" (p6.5): pick a span, see what the report will
/// contain, and generate a print-friendly PDF shared through the system file
/// picker. Everything is built on-device.
class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  ReportRange _range = ReportRange.last6Months;
  bool _busy = false;

  Future<void> _generate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(clinicalReportControllerProvider)
          .generate(_range);
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            ReportExportSaved() => 'Report saved.',
            ReportExportCancelled() => 'Export cancelled.',
            ReportExportNoData() =>
              'Nothing to export yet — log some cycles first.',
          }),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceSpoken =
        ref.watch(reduceSpokenDetailProvider).valueOrNull ?? false;
    final model = ref.watch(reportModelProvider(_range));

    return Scaffold(
      appBar: AppBar(title: const Text('Export report for a doctor')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'This builds a plain, print-friendly PDF of your cycle history, '
              'symptoms and basal temperature to share with a clinician. It is '
              'made entirely on this device; you choose where to save it. The '
              'file name carries no personal details, and it states plainly '
              'that olf is not a medical device.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text('Range', style: theme.textTheme.titleMedium),
            ),
            RadioGroup<ReportRange>(
              groupValue: _range,
              onChanged: (v) =>
                  setState(() => _range = v ?? ReportRange.last6Months),
              child: Column(
                children: [
                  for (final r in ReportRange.values)
                    RadioListTile<ReportRange>(value: r, title: Text(r.label)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                "What's included",
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            model.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                "Couldn't read your data. Try again.",
                style: theme.textTheme.bodyMedium,
              ),
              data: (report) =>
                  _Preview(report: report, reduceSpoken: reduceSpoken),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy || !(model.valueOrNull?.hasAnyData ?? false)
                  ? null
                  : _generate,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Generate report'),
            ),
            if (_busy) ...const [
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.report, required this.reduceSpoken});

  final ClinicalReport report;
  final bool reduceSpoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = report.summary;
    final symptomDays = report.symptomFrequency.fold<int>(
      0,
      (a, f) => a + f.dayCount,
    );

    final lines = <String>[
      _count(report.cycles.length, 'cycle', 'cycles'),
      '${_count(report.symptomFrequency.length, 'symptom', 'symptoms')} '
          'across ${_count(symptomDays, 'day', 'days')}',
      _count(
        report.temperatureSeries.length,
        'temperature reading',
        'temperature readings',
      ),
      if (report.pregnancyEvents.isNotEmpty)
        _count(
          report.pregnancyEvents.length,
          'pregnancy loss / birth',
          'pregnancy loss / birth events',
        ),
      if (s.meanCycleLength != null)
        'Mean cycle length ${s.meanCycleLength} days '
            '(${s.shortestCycleLength}–${s.longestCycleLength})',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Covers ${formatDay(report.includedRange.start)} to '
              '${formatDay(report.includedRange.end)}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium,
                  semanticsLabel: spokenLabel(
                    reduceSpoken,
                    redacted: 'One line of report contents.',
                  ),
                ),
              ),
            if (report.retentionExcludedEarlierData) ...[
              const SizedBox(height: 8),
              Text(
                'Entries before ${formatDay(report.includedRange.start)} were '
                'already auto-deleted by your retention setting, so the report '
                'says so and leaves them out.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (!report.hasAnyData) ...[
              const SizedBox(height: 8),
              Text(
                'Nothing logged in this range yet.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
}
