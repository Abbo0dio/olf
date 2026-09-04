import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

import '../a11y/spoken_detail.dart';
import '../period/period_format.dart';

/// The cycle-phase wheel (p1.12): a glanceable circular, color-coded view of
/// where today sits in the cycle (menstrual / follicular / ovulatory /
/// luteal), with a marker for today.
///
/// **Correctable** the same way every other reading on this screen is: tap
/// anywhere on the ring and it opens the existing today quick-log flow — no
/// separate "tell us we're wrong" mechanism to build or maintain.
///
/// **Never color-only** (WCAG 1.4.1 / SC 1.4.11): the caption below the ring
/// states the current phase name and day count as visible text, and the
/// screen-reader label spells out every segment's date span as text too —
/// redacted to a generic form when "Reduce spoken detail" (p5.3) is on, the
/// same as every other sensitive reading on this screen. Colors are checked
/// against `core`'s WCAG contrast maths in `app/test/a11y/theme_contrast_test.dart`.
class CycleWheel extends StatelessWidget {
  const CycleWheel({
    super.key,
    required this.phase,
    required this.reduceSpoken,
    required this.onTap,
  });

  /// `null` when there is no safe anchor to draw a wheel from (see
  /// `currentCyclePhase`) — renders an honest placeholder instead of a
  /// fabricated phase.
  final CyclePhase? phase;
  final bool reduceSpoken;

  /// Routes to the same today quick-log entry point `_Summary` already wires
  /// up (`onLogTodayFlow`) — correcting today's entry is what corrects the
  /// wheel.
  final VoidCallback onTap;

  static const double _diameter = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = this.phase;

    return Column(
      children: [
        Center(
          child: Semantics(
            button: true,
            label: _semanticLabel(),
            onTap: onTap,
            // The visual InkWell/CustomPaint subtree carries its own touch
            // handling but no independent semantics — the explicit label +
            // onTap above is the single node a screen reader sees.
            child: ExcludeSemantics(
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: _diameter,
                    height: _diameter,
                    child: CustomPaint(
                      painter: _CycleWheelPainter(
                        phase: phase,
                        colors: _phaseColors(theme.colorScheme),
                        trackColor: theme.colorScheme.surfaceContainerHighest,
                        markerColor: theme.colorScheme.onSurface,
                        markerHaloColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          phase == null ? 'Log a period to see this' : phase.current.kind.label,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (phase != null) ...[
          const SizedBox(height: 2),
          Text(
            'Day ${phase.dayInPhase}',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  String _semanticLabel() {
    final phase = this.phase;
    if (phase == null) {
      return 'Cycle phase wheel. No period logged yet. '
          "Tap to log today's flow.";
    }
    return spokenDetail(
      reduceSpoken,
      full:
          'Cycle phase wheel. Currently ${phase.current.kind.label}, '
          'day ${phase.dayInPhase}. This cycle: '
          '${phase.segments.map(_describeSegment).join(' ')} '
          "Tap to log today's flow.",
      redacted: "Cycle phase available. Tap to log today's flow.",
    );
  }

  static String _describeSegment(CyclePhaseSegment segment) =>
      '${segment.kind.label} ${formatDay(segment.start)} '
      'to ${formatDay(segment.end)}.';

  static Map<CyclePhaseKind, Color> _phaseColors(ColorScheme scheme) => {
    CyclePhaseKind.menstrual: scheme.primary,
    CyclePhaseKind.follicular: scheme.secondary,
    CyclePhaseKind.ovulatory: scheme.tertiary,
    CyclePhaseKind.luteal: scheme.outline,
  };
}

class _CycleWheelPainter extends CustomPainter {
  _CycleWheelPainter({
    required this.phase,
    required this.colors,
    required this.trackColor,
    required this.markerColor,
    required this.markerHaloColor,
  });

  final CyclePhase? phase;
  final Map<CyclePhaseKind, Color> colors;
  final Color trackColor;
  final Color markerColor;
  final Color markerHaloColor;

  static const double _strokeWidth = 20;

  /// Minimum share of the ring a phase gets, so a very short estimate (e.g. a
  /// compressed follicular phase) stays legible rather than collapsing to an
  /// invisible sliver. The whole set is then renormalized back to a full
  /// circle, so an unusually short cycle shrinks its *other* phases a little
  /// to make room — a drawing trade-off, not a claim about the estimate
  /// (the day counts in the label/caption are never adjusted).
  static const double _minSweepFraction = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.butt;

    final phase = this.phase;
    if (phase == null) {
      strokePaint.color = trackColor;
      canvas.drawArc(rect, 0, 2 * math.pi, false, strokePaint);
      return;
    }

    final sweeps = _sweepAngles([
      for (final s in phase.segments) s.lengthInDays,
    ]);

    var start = -math.pi / 2; // 12 o'clock
    for (var i = 0; i < phase.segments.length; i++) {
      strokePaint.color = colors[phase.segments[i].kind]!;
      canvas.drawArc(rect, start, sweeps[i], false, strokePaint);
      start += sweeps[i];
    }

    // Today's marker, positioned within the current segment's arc,
    // proportional to day-in-phase — clamped to stay on the arc even when
    // overdue rather than orbiting past it.
    final current = phase.current;
    var angleStart = -math.pi / 2;
    for (var i = 0; i < phase.currentIndex; i++) {
      angleStart += sweeps[i];
    }
    final fraction = current.lengthInDays <= 0
        ? 0.5
        : (phase.dayInPhase / current.lengthInDays).clamp(0.0, 1.0);
    final markerAngle = angleStart + sweeps[phase.currentIndex] * fraction;
    final markerCenter =
        center + Offset(math.cos(markerAngle), math.sin(markerAngle)) * radius;

    // A surface-colored halo behind an onSurface dot reads clearly against
    // any of the four phase colors, since every phase color already clears
    // WCAG contrast against the surface color (theme_contrast_test.dart).
    canvas.drawCircle(
      markerCenter,
      _strokeWidth * 0.55,
      Paint()..color = markerHaloColor,
    );
    canvas.drawCircle(
      markerCenter,
      _strokeWidth * 0.32,
      Paint()..color = markerColor,
    );
  }

  List<double> _sweepAngles(List<int> lengths) {
    final total = lengths.fold<int>(0, (a, b) => a + b);
    final n = lengths.length;
    if (total <= 0) return List.filled(n, 2 * math.pi / n);
    final minAngle = 2 * math.pi * _minSweepFraction;
    final raw = [
      for (final l in lengths) math.max(2 * math.pi * l / total, minAngle),
    ];
    final rawTotal = raw.fold<double>(0, (a, b) => a + b);
    return [for (final a in raw) a * 2 * math.pi / rawTotal];
  }

  @override
  bool shouldRepaint(covariant _CycleWheelPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.markerColor != markerColor;
}
