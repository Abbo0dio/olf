import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';

/// Period CRUD over the opened database. Reading this before
/// [appDatabaseProvider] has resolved throws — dependants only build inside the
/// `data` branch of the database gate.
final periodRepositoryProvider = Provider<PeriodRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftPeriodRepository(db);
});

/// Every logged period, live, most recent start first.
///
/// Not `autoDispose` — the calendar screen always listens, and disposing a
/// drift stream mid-frame leaves a close timer pending (which trips widget
/// tests). Same reasoning as `mostRecentPeriodStartProvider` in p0.4.
final periodsProvider = StreamProvider<List<Period>>((ref) {
  return ref.watch(periodRepositoryProvider).watchPeriods();
});
