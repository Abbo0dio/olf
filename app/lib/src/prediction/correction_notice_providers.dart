import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

/// Holds the transient "your update was taken in" note (p3.3).
///
/// In-memory session state only — a correction is just an edit to a logged
/// period (derived-on-read picks it up), so there is nothing to persist and no
/// correction-event history. `null` when no note is showing.
class CorrectionNotice extends Notifier<PredictionDelta?> {
  @override
  PredictionDelta? build() => null;

  /// Show the note for [delta]. Replaces any note already showing.
  void show(PredictionDelta delta) => state = delta;

  /// Clear the note (manual dismiss, auto-expiry, or an undone delete).
  void clear() => state = null;
}

final correctionNoticeProvider =
    NotifierProvider<CorrectionNotice, PredictionDelta?>(CorrectionNotice.new);
