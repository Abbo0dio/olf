import '../db/app_database.dart';
import '../health/health_sample.dart';

/// Reads and writes per-day basal body temperature ([BbtEntry]).
///
/// One row per calendar day, stored in **degrees Celsius**. The only rule is
/// plausibility (`validateCelsius`), enforced in [setTemp].
abstract interface class BbtRepository {
  /// The reading logged for [date], or `null` if that day has none.
  Future<BbtEntry?> tempOn(DateTime date);

  /// Every logged reading, newest day first, as a stream that re-emits on change.
  Stream<List<BbtEntry>> watchAll();

  /// Every logged reading, newest day first, as a one-shot read. The
  /// non-streaming companion to [watchAll] — used by batch jobs (the p6.2
  /// health-platform sync) that want a snapshot, not a subscription.
  Future<List<BbtEntry>> allEntries();

  /// Record (or replace) the reading for [date]. [celsius] must be in the
  /// plausible range or a [BbtException] is thrown. Upserts on the day and
  /// preserves `created_at` when a row already exists.
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
  Future<void> setTemp(
    DateTime date,
    double celsius, {
    HealthDataSource source = HealthDataSource.manual,
    String? externalId,
  });

  /// Remove the reading logged for [date]. A no-op if that day has none.
  Future<void> clearTemp(DateTime date);
}
