import '../date_math.dart';
import '../db/app_database.dart';
import '../prediction/date_range.dart';
import '../prediction/robust_predictor.dart' show fertileDaysAfterOvulation;
import 'cervical_mucus.dart';

/// The fertile window **as observed from cervical-mucus notes** in the current
/// cycle, or `null` when there is nothing fertile-quality logged yet.
///
/// This does not replace the statistical estimate from [RobustPredictor] (that
/// seam stays untouched for Phase 3) — the UI shows this alongside it as
/// "fertile signs from your notes". The span runs from the first fertile-quality
/// day (creamy or wetter) through [fertileDaysAfterOvulation] past the last one,
/// since peak fertility persists briefly after the fluid changes.
///
/// [cycleStart] is the current cycle's `periodStart`; observations before it or
/// after [today] are ignored.
DateRange? observedFertileWindow(
  Iterable<CervicalMucusEntry> entries, {
  required DateTime cycleStart,
  required DateTime today,
}) {
  final start = dateOnly(cycleStart);
  final t = dateOnly(today);

  DateTime? first;
  DateTime? last;
  for (final e in entries) {
    if (!e.type.isFertileQuality) continue;
    final day = dateOnly(e.date);
    if (day.isBefore(start) || day.isAfter(t)) continue;
    if (first == null || day.isBefore(first)) first = day;
    if (last == null || day.isAfter(last)) last = day;
  }
  if (first == null || last == null) return null;

  return DateRange(first, addDays(last, fertileDaysAfterOvulation));
}
