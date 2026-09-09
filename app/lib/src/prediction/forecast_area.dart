import 'package:flutter/material.dart';
import 'package:olf_core/olf_core.dart';

import '../modes/birth_control_recalibration_content.dart';
import '../modes/birth_control_recalibration_screen.dart';
import '../modes/pcos_correlation_format.dart';
import '../modes/perimenopause_format.dart';
import '../period/period_format.dart';
import 'prediction_format.dart';

/// The single "what goes where the forecast lives" widget on the home screen.
///
/// Replaces the old loose stack of independently-guarded blocks
/// (`_PredictionCard`, `_RecalibrationNote`, `_PerimenopausePausedNote`), which
/// could pile up when a user had two modes on at once. This renders **exactly
/// one** child (or nothing), by a fixed priority — first match wins:
///
/// 1. birth-control recalibration — [bcRecalActive]
/// 2. perimenopause paused        — [perimenopauseGapSuppress]
/// 3. pregnancy mode on           — render nothing (the week view is the mode
///    screen)
/// 4. overdue check-in            — `prediction.isOverdue`
/// 5. forecast card               — default, when `prediction != null`
/// 6. nothing                     — no prediction yet
///
/// Priorities 1–3 are the three conditions that withheld the prediction card in
/// the pre-consolidation code (`!bcRecalActive && !perimenopauseGapSuppress &&
/// !pregnancyModeOn`), so an overdue prediction under any of them shows the
/// mode's note, never the check-in — behaviour is unchanged. The one
/// consolidation win: if recalibration **and** a perimenopause gap both hold,
/// the recalibration card shows with the perimenopause note as its single
/// secondary line, instead of two stacked notes.
///
/// `_CorrectionNotice` (transient, `liveRegion`) and `_PregnancyStatusCard`
/// (post-loss/birth recovery, which already suppresses the prediction) stay
/// separate widgets in `period_calendar_page.dart`, rendered directly above
/// this one — they are semantically different and never meant to be folded in.
class ForecastArea extends StatelessWidget {
  const ForecastArea({
    super.key,
    required this.prediction,
    required this.bcRecalActive,
    required this.perimenopauseGapSuppress,
    required this.pregnancyModeOn,
    required this.reduceSpoken,
    required this.onLogPeriodStart,
    required this.onDismissRecalibration,
    this.observedFertileWindow,
    this.pcosMode = false,
    this.perimenopauseMode = false,
  });

  /// The current statistical prediction, or null when there isn't one yet.
  final CyclePrediction? prediction;

  /// A hormonal birth-control change is still settling (p7.8) — withholds the
  /// forecast entirely.
  final bool bcRecalActive;

  /// Perimenopause mode is on and history shows a long gap / 12+ months since
  /// the last period, so the forecast is withheld (p7.7).
  final bool perimenopauseGapSuppress;

  /// Pregnancy mode is on — the forecast card is hidden (not deleted) while it
  /// is, because the week view is the mode's own screen (p7.2b).
  final bool pregnancyModeOn;

  /// "Reduce spoken detail" — sensitive read-outs announce only that an entry
  /// exists (p5.3). Threaded straight into the forecast card.
  final bool reduceSpoken;

  /// Opens the period-dates editor. Wired to the overdue card's "Log period
  /// start" action.
  final VoidCallback onLogPeriodStart;

  /// Dismisses the birth-control recalibration note early (p7.8).
  final VoidCallback onDismissRecalibration;

  /// Fertile window observed from this cycle's cervical-mucus notes (p1.6).
  final DateRange? observedFertileWindow;

  /// p7.4: PCOS mode softens the forecast wording (wider interval).
  final bool pcosMode;

  /// p7.7: perimenopause mode softens the forecast wording (wider interval).
  /// Only reaches the card when the forecast is shown — a long gap withholds it
  /// via [perimenopauseGapSuppress] instead.
  final bool perimenopauseMode;

  @override
  Widget build(BuildContext context) {
    final child = _child();
    if (child == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 16), child: child);
  }

  Widget? _child() {
    // 1. Birth-control recalibration — withholds the forecast while a hormonal
    //    change settles. If a perimenopause gap also holds, its note becomes
    //    this card's one secondary line rather than a second stacked note.
    if (bcRecalActive) {
      return _RecalibrationNote(
        onDismiss: onDismissRecalibration,
        secondaryLine: perimenopauseGapSuppress
            ? perimenopauseForecastSuppressedNote
            : null,
      );
    }

    // 2. Perimenopause paused — a long gap withholds the forecast.
    if (perimenopauseGapSuppress) {
      return const _PerimenopausePausedNote();
    }

    // 3. Pregnancy mode on — the week view is the mode screen.
    if (pregnancyModeOn) return null;

    // 4 & 5. The prediction card — overdue check-in or forecast, chosen inside
    //        the widget by `prediction.isOverdue`. Only reached when none of the
    //        three suppression conditions above hold, matching the pre-r1
    //        `!bcRecalActive && !perimenopauseGapSuppress && !pregnancyModeOn`
    //        guard exactly.
    final p = prediction;
    if (p != null) {
      return _PredictionCard(
        prediction: p,
        observedFertileWindow: observedFertileWindow,
        reduceSpoken: reduceSpoken,
        pcosMode: pcosMode,
        perimenopauseMode: perimenopauseMode,
        onLogPeriodStart: onLogPeriodStart,
      );
    }

    // 6. Nothing to show yet.
    return null;
  }
}

/// The headline forecast: the next-period and fertile windows as **ranges**
/// with a confidence note — or, when a period is late, a calm check-in that
/// does **not** roll the estimate forward (it still shows the from-last-period
/// dates and asks the user to log the real start).
class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.prediction,
    required this.onLogPeriodStart,
    required this.reduceSpoken,
    this.pcosMode = false,
    this.perimenopauseMode = false,
    this.observedFertileWindow,
  });

  final CyclePrediction prediction;
  final VoidCallback onLogPeriodStart;
  final bool reduceSpoken;

  /// p7.4: append a wider-interval note (PCOS cycles vary more, so the range is
  /// wide and the estimate loose). The prediction itself is unchanged.
  final bool pcosMode;

  /// p7.7: append a wider-interval note (cycle length gets more variable through
  /// the perimenopause transition). The prediction itself is unchanged. When
  /// history shows a long gap the card is withheld upstream instead.
  final bool perimenopauseMode;

  /// Fertile window observed from this cycle's cervical-mucus notes (p1.6).
  /// Shown as an extra line alongside the statistical estimate when present.
  final DateRange? observedFertileWindow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = prediction.isOverdue;
    return Semantics(
      container: true,
      label: _semanticLabel(),
      child: Card(
        // The parent (`ForecastArea`, inside the home scroll) already insets and
        // spaces this card; take only the theme's shape / elevation / colour.
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        // The single screen accent stays on the forecast card. The overdue
        // check-in keeps the same surface — it is set apart by a leading icon
        // and a thin error edge (see `_overdue`), not a full background flip.
        color: theme.colorScheme.primaryContainer,
        shape: overdue
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.error, width: 1.5),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: overdue ? _overdue(context) : _forecast(context),
        ),
      ),
    );
  }

  Widget _forecast(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;
    final expected = formatDay(prediction.nextPeriodExpected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Next period',
              style: theme.textTheme.labelMedium?.copyWith(color: onColor),
            ),
            const Spacer(),
            Text(
              confidenceLabel(prediction.confidence),
              style: theme.textTheme.labelSmall?.copyWith(color: onColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatDateRange(prediction.nextPeriod),
          style: theme.textTheme.titleLarge?.copyWith(color: onColor),
        ),
        const SizedBox(height: 2),
        Text(
          prediction.status == PredictionStatus.dueNow
              ? 'Expected around now — most likely $expected'
              : 'Most likely $expected',
          style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 12),
        Text(
          'Fertile window (estimate)',
          style: theme.textTheme.labelMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 2),
        Text(
          formatDateRange(prediction.fertileWindow),
          style: theme.textTheme.bodyLarge?.copyWith(color: onColor),
        ),
        if (observedFertileWindow != null) ...[
          const SizedBox(height: 4),
          Text(
            'Fertile signs (from your notes): '
            '${formatDateRange(observedFertileWindow!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          confidenceNote(prediction),
          style: theme.textTheme.bodySmall?.copyWith(color: onColor),
        ),
        if (pcosMode) ...[
          const SizedBox(height: 4),
          Text(
            pcosWiderIntervalNote,
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
        if (perimenopauseMode) ...[
          const SizedBox(height: 4),
          Text(
            perimenopauseWiderIntervalNote,
            style: theme.textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
      ],
    );
  }

  Widget _overdue(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_busy_outlined, size: 20, color: onColor),
            const SizedBox(width: 8),
            Text(
              'Period check-in',
              style: theme.textTheme.labelMedium?.copyWith(color: onColor),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          overdueHeadline(prediction.daysPastExpected!),
          style: theme.textTheme.titleMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 6),
        Text(
          overdueBody,
          style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: onLogPeriodStart,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Log period start'),
          ),
        ),
      ],
    );
  }

  String _semanticLabel() {
    // p5.3: with "Reduce spoken detail" on, the forecast dates are not spoken —
    // just that a prediction is on screen.
    if (reduceSpoken) {
      return prediction.isOverdue
          ? 'Period check-in available. Open the calendar for details.'
          : 'Next period prediction available. Open the calendar for the dates.';
    }
    if (prediction.isOverdue) {
      return 'Period check-in. '
          '${overdueHeadline(prediction.daysPastExpected!)}. $overdueBody';
    }
    final signs = observedFertileWindow == null
        ? ''
        : 'Fertile signs from your notes '
              '${formatDateRange(observedFertileWindow!)}. ';
    final widerNote = pcosMode
        ? ' $pcosWiderIntervalNote'
        : perimenopauseMode
        ? ' $perimenopauseWiderIntervalNote'
        : '';
    return 'Next period estimated ${formatDateRange(prediction.nextPeriod)}, '
        'most likely ${formatDay(prediction.nextPeriodExpected)}. '
        'Fertile window estimated ${formatDateRange(prediction.fertileWindow)}. '
        '$signs${confidenceNote(prediction)}$widerNote';
  }
}

/// p7.8: shown in place of the forecast card while a hormonal birth-control
/// change is still settling. A plain, non-alarming note — no method name, no
/// diagnosis — with a way into the guided explainer and a way to dismiss it
/// early. Only rendered when the birth-control-change mode is on and the
/// recalibration window is active (see `birthControlRecalibrationProvider`).
class _RecalibrationNote extends StatelessWidget {
  const _RecalibrationNote({required this.onDismiss, this.secondaryLine});

  final VoidCallback onDismiss;

  /// r1: one extra line when a perimenopause gap also holds — the two notes
  /// used to stack. Existing copy (`perimenopauseForecastSuppressedNote`),
  /// reused verbatim.
  final String? secondaryLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const note = BirthControlRecalibrationContent.predictionCardNote;

    return Semantics(
      container: true,
      label: secondaryLine == null ? note : '$note $secondaryLine',
      // Neutral surface (theme `Card`) — one accent per screen, and it belongs
      // to the forecast card. Existing icon carries the meaning, not colour.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.timelapse_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (secondaryLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryLine!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BirthControlRecalibrationScreen(),
                      ),
                    ),
                    child: const Text('Learn more'),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
              Text(
                BirthControlRecalibrationContent.notMedicalDeviceLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// p7.7: shown in place of the forecast card while perimenopause mode is on and
/// the logged history shows a long gap / 12+ months since the last period. A
/// plain, non-alarming note — longer and skipped cycles are the expected signal
/// in this stage, so the estimate pauses rather than asserting a forecast built
/// on pre-gap cycles.
class _PerimenopausePausedNote extends StatelessWidget {
  const _PerimenopausePausedNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: perimenopauseForecastSuppressedNote,
      // Neutral surface (theme `Card`); the icon, not colour, marks it out.
      child: Card(
        // Purely visual — the wrapping Semantics is the semantic container.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.timelapse_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  perimenopauseForecastSuppressedNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
