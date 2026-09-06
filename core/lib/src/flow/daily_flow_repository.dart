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
  ///
  /// [externalId] is **sticky on update**: passing `null` over a row that
  /// already carries an id keeps the existing id, so an edit that flips a
  /// previously-imported row back to `manual` still lets a p6.4 write-back
  /// update the platform record in place. Pass a non-null id to replace it.
  ///
  /// [sourceDevice] (schema v11, p8.2) is the free-form device / app tag for a
  /// health-platform import (an Oura Ring, a Garmin watch). It is **not** sticky:
  /// an in-app edit passes no tag and the row's `source_device` is cleared to
  /// `null` (the value is now the user's own). Only the health-import path
  /// passes a non-null tag.
  Future<void> setFlow(
    DateTime date, {
    required FlowIntensity intensity,
    ClotSize? clotSize,
    HealthDataSource source = HealthDataSource.manual,
    String? externalId,
    String? sourceDevice,
  });

  /// Remove the flow logged for [date]. A no-op if that day has none.
  Future<void> clearFlow(DateTime date);
}
