import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';

/// Per-day flow CRUD over the opened database. Only valid inside the `data`
/// branch of the database gate (see [appDatabaseProvider]).
final dailyFlowRepositoryProvider = Provider<DailyFlowRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftDailyFlowRepository(db);
});

/// Every logged day, live. Not `autoDispose` — the calendar always listens, and
/// disposing a drift stream mid-frame leaves a close timer pending (trips widget
/// tests). Same reasoning as `periodsProvider`.
final dailyFlowsProvider = StreamProvider<List<DailyFlow>>((ref) {
  return ref.watch(dailyFlowRepositoryProvider).watchAll();
});
