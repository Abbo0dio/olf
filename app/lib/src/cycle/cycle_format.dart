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
String cycleLengthNote(Cycle cycle) {
  if (cycle.isCurrent) return 'Current cycle';
  if (cycle.isLikelyGap) {
    return '${cycle.lengthInDays}-day gap — a period may not have been logged';
  }
  return '${cycle.lengthInDays}-day cycle';
}

/// A plain-language summary of [stats] for the cycle card and its screen-reader
/// label. Never invents a number it does not have — with no history it asks for
/// more logging rather than assuming any cycle length.
String summariseStats(CycleStats stats) {
  final typical = stats.typicalCycleLength;
  if (typical == null) {
    const base =
        'Log at least two periods to see your typical cycle length and how '
        'much it varies.';
    return stats.hasLikelyGap
        ? '$base One long stretch looks like a period may not have been '
              'logged.'
        : base;
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
  }
  buffer.write('.');
  if (stats.typicalPeriodLength != null) {
    buffer.write(' Typical period ${stats.typicalPeriodLength} days.');
  }
  if (stats.hasLikelyGap) {
    buffer.write(
      ' One long gap is set aside — a period may not have been logged then.',
    );
  }
  return buffer.toString();
}
