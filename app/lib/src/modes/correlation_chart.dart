import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

/// Shared cycle-phase-banded bar for the condition modes (first landed for PCOS,
/// p7.4; reused by endometriosis / PMDD / perimenopause, p7.5–p7.7).
///
/// Shows how one category's logged days split across the four cycle phases: a
/// single horizontal bar banded menstrual → follicular → ovulatory → luteal,
/// each band's width proportional to its share of the placed days, with a
/// legend of plain counts underneath. Colour is never the only signal — every
/// band and legend row is labelled in text, and the whole widget carries one
/// [Semantics] summary for screen readers.
///
/// Descriptive only: it draws what was logged, it makes no claim about cause.
class CorrelationChart extends StatelessWidget {
  const CorrelationChart({
    super.key,
    required this.label,
    required this.daysByPhase,
  });

  /// The category this bar describes (a symptom name, a flare marker …) — used
  /// in the screen-reader summary.
  final String label;

  /// Placed days per phase, as returned in [PhaseCorrelation.daysByPhase].
  final Map<CyclePhaseKind, int> daysByPhase;

  int get _placed => daysByPhase.values.fold(0, (sum, n) => sum + n);

  static Color _phaseColor(ColorScheme scheme, CyclePhaseKind kind) =>
      switch (kind) {
        CyclePhaseKind.menstrual => scheme.primary,
        CyclePhaseKind.follicular => scheme.secondary,
        CyclePhaseKind.ovulatory => scheme.tertiary,
        CyclePhaseKind.luteal => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placed = _placed;

    final summary = StringBuffer('$label across cycle phase: ');
    if (placed == 0) {
      summary.write('no logged days fall inside a cycle phase yet.');
    } else {
      summary.write(
        CyclePhaseKind.values
            .map((k) => '${k.label} ${daysByPhase[k] ?? 0}')
            .join(', '),
      );
      summary.write('.');
    }

    return Semantics(
      container: true,
      label: summary.toString(),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: placed == 0
                    ? ColoredBox(color: scheme.surfaceContainerHighest)
                    : Row(
                        children: [
                          for (final kind in CyclePhaseKind.values)
                            if ((daysByPhase[kind] ?? 0) > 0)
                              Expanded(
                                flex: daysByPhase[kind]!,
                                child: ColoredBox(
                                  color: _phaseColor(scheme, kind),
                                ),
                              ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final kind in CyclePhaseKind.values)
                  _LegendItem(
                    color: _phaseColor(scheme, kind),
                    text: '${kind.label} ${daysByPhase[kind] ?? 0}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.text,
    required this.style,
  });

  final Color color;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
}
