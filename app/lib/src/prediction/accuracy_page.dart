import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accuracy_format.dart';
import 'accuracy_providers.dart';

/// A private, on-device view of how close past period estimates were, for the
/// user's own history (p3.5).
///
/// Reached from Settings → Cycle → "Prediction accuracy". Everything is computed
/// locally by the core backtest harness on open; no number is ever fabricated
/// (too little history shows a keep-logging prompt), and the screen makes no
/// accuracy claim of its own — it just shows the user their figure and the
/// sample size behind it.
class AccuracyPage extends ConsumerWidget {
  const AccuracyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(accuracyReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(accuracyScreenTitle)),
      body: switch (report) {
        AsyncData(:final value) => _Body(report: value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              accuracyErrorLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        _ => Center(
          child: Semantics(
            label: accuracyWorkingLabel,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  accuracyWorkingLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});

  final AccuracyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!report.hasEnough) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(accuracyThinHistory, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          _PrivacyNote(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(accuracyIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Semantics(
          label: accuracySampleSize(report.scoredPoints),
          child: Text(
            accuracySampleSize(report.scoredPoints),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _MetricTile(
          label: accuracyTypicalMissLabel,
          value: accuracyDays(report.meanAbsErrorDays),
          hint: accuracyTypicalMissHint,
        ),
        _MetricTile(
          label: accuracyMedianMissLabel,
          value: accuracyDays(report.medianAbsErrorDays),
          hint: accuracyMedianMissHint,
        ),
        _MetricTile(
          label: accuracyInRangeLabel,
          value: accuracyPercent(report.coverage),
        ),
        const SizedBox(height: 24),
        Text(
          accuracyTrendLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _Trend(errors: report.perDecisionAbsErrorDays),
        const SizedBox(height: 24),
        _PrivacyNote(),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value.${hint == null ? '' : ' $hint'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Text(label, style: theme.textTheme.bodyLarge)),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The per-estimate error series — a plain sparkline (no charting package), or a
/// text range when there are too few points to draw a meaningful line.
class _Trend extends StatelessWidget {
  const _Trend({required this.errors});

  final List<int> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (errors.length < 2) {
      return Text(
        errors.isEmpty ? '—' : '${errors.single} days',
        style: theme.textTheme.bodyMedium,
      );
    }
    return Semantics(
      label: accuracyTrendSemantics(errors),
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            errors: errors,
            line: theme.colorScheme.primary,
            baseline: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.errors,
    required this.line,
    required this.baseline,
  });

  final List<int> errors;
  final Color line;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final maxError = errors.reduce((a, b) => a > b ? a : b).toDouble();
    final span = maxError <= 0 ? 1.0 : maxError;
    final dx = errors.length == 1 ? 0.0 : size.width / (errors.length - 1);

    final zeroY = size.height - 1;
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final path = Path();
    for (var i = 0; i < errors.length; i++) {
      final x = dx * i;
      final y = zeroY - (errors[i] / span) * (size.height - 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.errors != errors || old.line != line || old.baseline != baseline;
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            accuracyPrivacyNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
