import '../date_math.dart';
import 'predictor.dart';

/// Why a prediction was recomputed — shapes the wording of a [PredictionDelta].
class PredictionChangeContext {
  const PredictionChangeContext({
    this.followedCorrection = false,
    this.cyclesAdded = 0,
  }) : assert(cyclesAdded >= 0);

  /// The recompute followed the user fixing a logged date. When true, the delta
  /// **always** produces at least one reason — a correction is never shown as
  /// having silently done nothing (`requirements.md` §9(1)).
  final bool followedCorrection;

  /// How many completed cycles were logged between `before` and `after`.
  final int cyclesAdded;
}

/// A plain-language diff of two [CyclePrediction]s — the "here's what changed"
/// substrate the correction-loop UI (p3.3) renders.
///
/// Pure value object built by [PredictionDelta.between]; no `DateTime.now()`, no
/// persistence. All wording is **gender-neutral** ("you" / "your") and
/// **non-alarming** (a shift is "moved" / "updated", never "wrong" / "error").
class PredictionDelta {
  const PredictionDelta({
    required this.expectedShiftDays,
    required this.rangeWidthChangeDays,
    required this.earliestShiftDays,
    required this.latestShiftDays,
    required this.confidenceBefore,
    required this.confidenceAfter,
    required this.appeared,
    required this.withdrawn,
    required this.reasons,
  });

  /// Signed whole days the expected date moved: positive = later, negative =
  /// earlier.
  final int expectedShiftDays;

  /// Signed whole days the predicted range width changed: positive = wider,
  /// negative = narrower.
  final int rangeWidthChangeDays;

  /// Signed shift of the range's near / far edge (positive = later).
  final int earliestShiftDays;
  final int latestShiftDays;

  /// Confidence on each side; `null` where there was no prediction.
  final PredictionConfidence? confidenceBefore;
  final PredictionConfidence? confidenceAfter;

  /// A prediction became available where there was none.
  final bool appeared;

  /// A prediction that existed was withdrawn (not enough usable history now).
  final bool withdrawn;

  /// Human-readable lines describing the change, most important first. Never
  /// empty when [PredictionChangeContext.followedCorrection] is set.
  final List<String> reasons;

  /// Whole-day threshold below which a shift is treated as "no change".
  static const int dayThreshold = 1;

  bool get confidenceChanged => confidenceBefore != confidenceAfter;

  /// True when something a user would notice actually moved.
  bool get isMeaningful =>
      appeared ||
      withdrawn ||
      expectedShiftDays.abs() >= dayThreshold ||
      rangeWidthChangeDays.abs() >= dayThreshold ||
      confidenceChanged;

  static PredictionDelta between({
    required CyclePrediction? before,
    required CyclePrediction? after,
    PredictionChangeContext context = const PredictionChangeContext(),
  }) {
    final appeared = before == null && after != null;
    final withdrawn = before != null && after == null;

    var expectedShift = 0;
    var widthChange = 0;
    var earliestShift = 0;
    var latestShift = 0;
    if (before != null && after != null) {
      expectedShift = daysBetween(
        before.nextPeriodExpected,
        after.nextPeriodExpected,
      );
      earliestShift = daysBetween(
        before.nextPeriod.start,
        after.nextPeriod.start,
      );
      latestShift = daysBetween(before.nextPeriod.end, after.nextPeriod.end);
      final beforeWidth = daysBetween(
        before.nextPeriod.start,
        before.nextPeriod.end,
      );
      final afterWidth = daysBetween(
        after.nextPeriod.start,
        after.nextPeriod.end,
      );
      widthChange = afterWidth - beforeWidth;
    }

    final base = PredictionDelta(
      expectedShiftDays: expectedShift,
      rangeWidthChangeDays: widthChange,
      earliestShiftDays: earliestShift,
      latestShiftDays: latestShift,
      confidenceBefore: before?.confidence,
      confidenceAfter: after?.confidence,
      appeared: appeared,
      withdrawn: withdrawn,
      reasons: const [],
    );

    return base._withReasons(_reasons(base, context));
  }

  PredictionDelta _withReasons(List<String> reasons) => PredictionDelta(
    expectedShiftDays: expectedShiftDays,
    rangeWidthChangeDays: rangeWidthChangeDays,
    earliestShiftDays: earliestShiftDays,
    latestShiftDays: latestShiftDays,
    confidenceBefore: confidenceBefore,
    confidenceAfter: confidenceAfter,
    appeared: appeared,
    withdrawn: withdrawn,
    reasons: reasons,
  );

  static List<String> _reasons(PredictionDelta d, PredictionChangeContext ctx) {
    final lead = ctx.followedCorrection
        ? 'Your correction was applied.'
        : ctx.cyclesAdded == 1
        ? 'You logged another cycle.'
        : ctx.cyclesAdded > 1
        ? 'You logged ${ctx.cyclesAdded} more cycles.'
        : 'Your history changed.';

    if (d.appeared) {
      return [
        ctx.followedCorrection
            ? '$lead There is now enough history to show a prediction.'
            : '$lead A prediction is now available.',
      ];
    }
    if (d.withdrawn) {
      return [
        '$lead This prediction has been paused until there is enough recent '
            'history again.',
      ];
    }

    if (!d.isMeaningful) {
      // Never let a correction look like it did nothing.
      return ctx.followedCorrection || ctx.cyclesAdded > 0
          ? ['$lead The prediction did not need to change.']
          : const [];
    }

    final out = <String>[lead];

    if (d.expectedShiftDays != 0) {
      final n = d.expectedShiftDays.abs();
      final dir = d.expectedShiftDays > 0 ? 'later' : 'earlier';
      out.add('The expected date moved ${_days(n)} $dir.');
    }
    if (d.rangeWidthChangeDays != 0) {
      final n = d.rangeWidthChangeDays.abs();
      final how = d.rangeWidthChangeDays > 0 ? 'widened' : 'narrowed';
      out.add('The expected range $how by ${_days(n)}.');
    }
    if (d.confidenceChanged &&
        d.confidenceBefore != null &&
        d.confidenceAfter != null) {
      final rose = d.confidenceAfter!.index > d.confidenceBefore!.index;
      out.add(
        'Confidence in this prediction ${rose ? 'went up' : 'went down'}, '
        'from ${_confidence(d.confidenceBefore!)} to '
        '${_confidence(d.confidenceAfter!)}.',
      );
    }
    return out;
  }

  static String _days(int n) => n == 1 ? '1 day' : '$n days';

  static String _confidence(PredictionConfidence c) => switch (c) {
    PredictionConfidence.low => 'low',
    PredictionConfidence.medium => 'medium',
    PredictionConfidence.high => 'high',
  };
}
