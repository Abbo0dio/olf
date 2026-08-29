import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../period/period_providers.dart';
import '../providers.dart';

/// Reads and writes pregnancy-end markers (p1.11). Only valid inside the
/// database `data` branch, like the other repository providers.
final cycleEventRepositoryProvider = Provider<CycleEventRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftCycleEventRepository(db);
});

/// Every recorded pregnancy loss / birth, live, oldest first. Empty until the
/// stream loads.
final pregnancyEventsProvider = StreamProvider<List<PregnancyEvent>>((ref) {
  return ref.watch(cycleEventRepositoryProvider).watchPregnancyEvents();
});

/// Where the user sits relative to a recorded pregnancy end — drives the home
/// banner and nothing else. `none` unless a loss / birth is the most recent
/// pregnancy event *and* no period has been logged since.
final pregnancyRecoveryStateProvider = Provider<PregnancyRecoveryState>((ref) {
  final events =
      ref.watch(pregnancyEventsProvider).value ?? const <PregnancyEvent>[];
  final periods = ref.watch(periodsProvider).value ?? const <Period>[];
  return pregnancyRecoveryState(events: events, periods: periods);
});

/// The most recent recorded pregnancy end, or `null`.
final mostRecentPregnancyEndProvider = Provider<PregnancyEvent?>((ref) {
  final events =
      ref.watch(pregnancyEventsProvider).value ?? const <PregnancyEvent>[];
  return mostRecentPregnancyEnd(events);
});
