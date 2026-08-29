import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

import 'bbt_format.dart';

/// A small self-contained basal-temperature chart for one cycle — a plain
/// `CustomPaint` line-and-dot plot, no charting package (keeps the dependency
/// surface clean). X is the cycle day, Y is temperature in [unit].
class BbtChart extends StatelessWidget {
  const BbtChart({
    super.key,
    required this.points,
    required this.unit,
    this.height = 160,
  });

  final List<BbtChartPoint> points;
  final TemperatureUnit unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return const SizedBox.shrink();
    }

    final celsiusValues = points.map((p) => p.celsius);
    final loC = celsiusValues.reduce((a, b) => a < b ? a : b);
    final hiC = celsiusValues.reduce((a, b) => a > b ? a : b);
    final firstDay = points.first.cycleDay;
    final lastDay = points.last.cycleDay;

    final semantic =
        'Basal temperature chart: ${points.length} readings between '
        '${formatTemp(loC, unit)} and ${formatTemp(hiC, unit)}, '
        'cycle day $firstDay to $lastDay.';

    return Semantics(
      label: semantic,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _BbtChartPainter(
            points: points,
            unit: unit,
            lineColor: theme.colorScheme.primary,
            dotColor: theme.colorScheme.primary,
            axisColor: theme.colorScheme.outlineVariant,
            labelStyle:
                theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ) ??
                const TextStyle(fontSize: 11),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BbtChartPainter extends CustomPainter {
  _BbtChartPainter({
    required this.points,
    required this.unit,
    required this.lineColor,
    required this.dotColor,
    required this.axisColor,
    required this.labelStyle,
  });

  final List<BbtChartPoint> points;
  final TemperatureUnit unit;
  final Color lineColor;
  final Color dotColor;
  final Color axisColor;
  final TextStyle labelStyle;

  static const double _leftPad = 44;
  static const double _bottomPad = 18;
  static const double _topPad = 8;
  static const double _rightPad = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final loC = points.map((p) => p.celsius).reduce((a, b) => a < b ? a : b);
    final hiC = points.map((p) => p.celsius).reduce((a, b) => a > b ? a : b);
    // Pad the Y range so the line never rides the edges; guarantee a span.
    final span = (hiC - loC).clamp(0.2, double.infinity);
    final yMin = loC - span * 0.15;
    final yMax = hiC + span * 0.15;

    final firstDay = points.first.cycleDay;
    final lastDay = points.last.cycleDay;
    final xSpan = (lastDay - firstDay).clamp(1, 1 << 30);

    final plot = Rect.fromLTRB(
      _leftPad,
      _topPad,
      size.width - _rightPad,
      size.height - _bottomPad,
    );

    double dx(int cycleDay) =>
        plot.left + (cycleDay - firstDay) / xSpan * plot.width;
    double dy(double celsius) =>
        plot.bottom - (celsius - yMin) / (yMax - yMin) * plot.height;

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    // Y axis + baseline.
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);

    // Y tick labels: min and max.
    _label(canvas, formatTempValue(yMax, unit), Offset(4, plot.top - 6));
    _label(canvas, formatTempValue(yMin, unit), Offset(4, plot.bottom - 6));

    // X labels: first and last cycle day.
    _label(canvas, 'Day $firstDay', Offset(plot.left - 8, plot.bottom + 4));
    _label(canvas, 'Day $lastDay', Offset(plot.right - 44, plot.bottom + 4));

    // The temperature line.
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(dx(points.first.cycleDay), dy(points.first.celsius));
    for (final p in points.skip(1)) {
      path.lineTo(dx(p.cycleDay), dy(p.celsius));
    }
    canvas.drawPath(path, linePaint);

    // Dots.
    final dotPaint = Paint()..color = dotColor;
    for (final p in points) {
      canvas.drawCircle(Offset(dx(p.cycleDay), dy(p.celsius)), 3, dotPaint);
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_BbtChartPainter old) =>
      old.points != points || old.unit != unit || old.lineColor != lineColor;
}
