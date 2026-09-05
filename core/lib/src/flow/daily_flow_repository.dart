import '../db/app_database.dart';
import '../db/tables.dart';
import '../health/health_sample.dart';

/// Reads and writes per-day flow logs ([DailyFlow]).
///
/// One row per calendar day. There is nothing to validate — any [FlowIntensity]
/// is acceptable and clots are optional — so this is a plain CRUD seam. The UI
/// decides *when* to offer logging (period days + today).
abstract interface class DailyFlowRepository {
  /// The flow logged for [date], or `null` if that day has none.
  Future<DailyFlow?> flowOn(DateTime date);

  /// Every logged day as a stream that re-emits on any change.
  Stream<List<DailyFlow>> watchAll();

  /// Every logged day, newest first, as a one-shot read. The non-streaming
  /// companion to [watchAll] — used by batch jobs (the p6.2 health-platform
  /// sync) that want a snapshot, not a subscription.
  Future<List<DailyFlow>> allFlows();

  /// Record (or replace) the flow for [date]. Upserts on the day; `created_at`
  /// is preserved when a row already exists.
  ///
  /// [source] / [externalId] are the schema-v7 provenance columns (p6.1). A
  /// normal in-app edit leaves them at the default ([HealthDataSource.manual] /
  /// `null`); a health-platform import (p6.2+) passes the platform source and
  /// the sample's stable id so a later sync matches instead of duplicating.
  Future<void> setFlow(
    DateTime date, {
    required FlowIntensity intensity,
    ClotSize? clotSize,
    HealthDataSource source = HealthDataSource.manual,
    String? externalId,
  });

  /// Remove the flow logged for [date]. A no-op if that day has none.
  Future<void> clearFlow(DateTime date);
}
