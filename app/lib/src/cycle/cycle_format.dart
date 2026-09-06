import 'package:olf_core/olf_core.dart';

/// Short label for a variability bucket, e.g. `Mostly regular`.
extension CycleRegularityLabel on CycleRegularity {
  String get label => switch (this) {
    CycleRegularity.notEnoughData => 'Not enough data yet',
    CycleRegularity.regular => 'Regular',
    CycleRegularity.mostlyRegular => 'Mostly regular',
    CycleRegularity.irregular => 'Irregular',
  };
}

/// A cycle's length as a short note for a history row, e.g. `29-day cycle`.
/// The current (still-open) cycle has no length yet.
///
/// [pcosMode] (p7.4) only softens the likely-gap wording — long gaps are framed
/// as expected rather than as a missed entry. The cycle itself is unchanged.
String cycleLengthNote(Cycle cycle, {bool pcosMode = false}) {
  if (cycle.isCurrent) return 'Current cycle';
  if (cycle.isLikelyGap) {
    return pcosMode
        ? '${cycle.lengthInDays}-day gap — long gaps are common with PCOS'
        : '${cycle.lengthInDays}-day gap — a period may not have been logged';
  }
  return '${cycle.lengthInDays}-day cycle';
}

/// A plain-language summary of [stats] for the cycle card and its screen-reader
/// label. Never invents a number it does not have — with no history it asks for
/// more logging rather than assuming any cycle length.
///
/// [pcosMode] (p7.4) only softens wording — long / variable cycles are framed as
/// expected rather than as a likely missed entry. The underlying [stats] are
/// unchanged; nothing about `deriveCycles` or the predictor differs.
String summariseStats(CycleStats stats, {bool pcosMode = false}) {
  final typical = stats.typicalCycleLength;
  if (typical == null) {
    const base =
        'Log at least two periods to see your typical cycle length and how '
        'much it varies.';
    if (!stats.hasLikelyGap) return base;
    return pcosMode
        ? '$base Long gaps between periods are common with PCOS.'
        : '$base One long stretch looks like a period may not have been '
              'logged.';
  }

  final buffer = StringBuffer('Typical cycle $typical days');
  if (stats.shortestCycleLength != stats.longestCycleLength) {
    buffer.write(
      ', ranging ${stats.shortestCycleLength}–${stats.longestCycleLength} '
      'days',
    );
  }
  buffer.write('. ${stats.regularity.label}');
  if (stats.regularity == CycleRegularity.notEnoughData) {
    buffer.write(' — one more cycle and variability shows here');
  } else if (pcosMode && stats.regularity == CycleRegularity.irregular) {
    buffer.write(' — expected in this mode');
  }
  buffer.write('.');
  if (stats.typicalPeriodLength != null) {
    buffer.write(' Typical period ${stats.typicalPeriodLength} days.');
  }
  if (stats.hasLikelyGap) {
    buffer.write(
      pcosMode
          ? ' A long stretch is set aside from the averages. Long gaps between '
                'periods are common with PCOS.'
          : ' One long gap is set aside — a period may not have been logged '
                'then.',
    );
  }
  return buffer.toString();
}
