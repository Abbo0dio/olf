import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../cycle/cycle_providers.dart';
import '../providers.dart';

/// PMDD daily-rating CRUD over the opened database (p7.6). Only valid inside the
/// `data` branch of the database gate (see [appDatabaseProvider]).
final pmddRatingRepositoryProvider = Provider<PmddRatingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftPmddRatingRepository(db);
});

/// Every stored PMDD rating row, newest first, live. Not `autoDispose` — the
/// screen and the rating sheet both listen (same reasoning as `symptomEntries`).
final pmddRatingsProvider = StreamProvider<List<PmddRating>>((ref) {
  return ref.watch(pmddRatingRepositoryProvider).watchAll();
});

/// Today's rating, as an item→severity map (empty when today is not rated).
final pmddTodayRatingProvider = Provider<Map<PmddSymptom, SymptomSeverity>>((
  ref,
) {
  final rows =
      ref.watch(pmddRatingsProvider).valueOrNull ?? const <PmddRating>[];
  final today = dateOnly(DateTime.now());
  return {
    for (final r in rows)
      if (dateOnly(r.date) == today) r.item: r.rating,
  };
});

/// The PMDD cycle-overlay (p7.6): rated + notable days bucketed by cycle phase,
/// plus the descriptive luteal read, via the p7.4 [cyclePhaseCorrelations] core.
/// `DateTime.now()` is read here at the edge, like `prediction_providers`.
/// `null` until the ratings stream has loaded.
final pmddOverlayProvider = Provider<PmddOverlay?>((ref) {
  final rows = ref.watch(pmddRatingsProvider).valueOrNull;
  if (rows == null) return null;

  final byDay = <DateTime, Map<PmddSymptom, SymptomSeverity>>{};
  for (final r in rows) {
    (byDay[dateOnly(r.date)] ??= <PmddSymptom, SymptomSeverity>{})[r.item] =
        r.rating;
  }

  return pmddOverlay(
    ratings: [
      for (final entry in byDay.entries)
        PmddDayRating(date: entry.key, items: entry.value),
    ],
    cycles: ref.watch(cyclesProvider),
    today: DateTime.now(),
  );
});
