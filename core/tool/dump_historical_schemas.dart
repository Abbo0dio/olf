// Regenerates the historical drift schema snapshots in `core/drift_schemas/`.
//
// We adopted drift's `schema dump` tooling at schema v6 (p5.6), so there is no
// historical record of v1..v5 to dump from source. This script reconstructs
// them from the committed **v6** snapshot.
//
// Why v6 is the anchor: v1..v6 is the entire *strictly additive* stretch of
// olf's migration history — every `onUpgrade` block up to v6 only `createTable`s
// and never alters an existing table (p1.11's pregnancy markers reuse the
// `cycle_events.type` TEXT column with no DDL change). So schema vN (N ≤ 6) is
// exactly the first N "waves" of tables from the v6 snapshot, each table
// byte-identical to its v6 form — full Dart metadata (type converters,
// `dateTime` mapping) preserved, which a dump from a bare `.db` file would lose.
//
// **v7 (p6.1) is the first migration that ALTERs an existing table** (adds
// `source` + `external_id` to `bbt_entries` and `daily_flows`). Truncation
// cannot express a column-level change, so v7 is **not** reconstructed here — it
// is its own real `drift_dev schema dump` and this script only sanity-checks
// that it was regenerated after the `schemaVersion` bump. Any future ALTER
// version is handled the same way: dump it, don't reconstruct it.
//
// Table order in the v6 snapshot follows the migrations:
//   v1 cycle_events
//   v2 + periods
//   v3 + daily_flows
//   v4 + symptom_types, daily_symptom_entries
//   v5 + bbt_entries, cervical_mucus_entries, app_settings
//   v6 + medications, birth_control_entries, reminders
//
// Usage, from `core/`:
//   dart run drift_dev schema dump lib/src/db/app_database.dart drift_schemas/
//   dart run tool/dump_historical_schemas.dart
//
// Adding a schema vN:
//   * additive-only (createTable) and N ≤ 6 would never happen again — history
//     past v6 is frozen;
//   * any new version: bump `schemaVersion`, add the `onUpgrade` block, run
//     `drift_dev schema dump` (writes `drift_schema_vN.json`), then run this
//     script (rebuilds v1..v5 from v6, checks vN exists), then
//     `drift_dev schema generate drift_schemas/ test/db/generated/`, and extend
//     `test/db/migration_matrix_test.dart`.

import 'dart:convert';
import 'dart:io';

/// Number of tables present at each historical schema version. Only the
/// additive-only stretch (v1..v5, reconstructed from the v6 anchor) lives here;
/// v6 is the anchor itself and v7+ are dumped, not reconstructed.
const Map<int, int> _tableCountAtVersion = {1: 1, 2: 2, 3: 3, 4: 5, 5: 8};

/// Schema versions that must exist as their own real `drift_dev schema dump`
/// (the anchor, plus every ALTER version). Checked, never rebuilt.
const List<int> _dumpedVersions = [6, 7];

void main() {
  final schemaDir = Directory('drift_schemas');
  final anchor = File('${schemaDir.path}/drift_schema_v6.json');
  if (!anchor.existsSync()) {
    stderr.writeln(
      'missing drift_schemas/drift_schema_v6.json — run '
      '`dart run drift_dev schema dump lib/src/db/app_database.dart '
      'drift_schemas/` first',
    );
    exit(2);
  }

  final v6 = jsonDecode(anchor.readAsStringSync()) as Map<String, dynamic>;
  final entities = (v6['entities'] as List).cast<Object?>();
  final fixedSql = (v6['fixed_sql'] as List?)?.cast<Object?>();

  final encoder = const JsonEncoder.withIndent('  ');

  for (final entry in _tableCountAtVersion.entries) {
    final version = entry.key;
    final count = entry.value;

    final snapshot = <String, dynamic>{
      '_meta': v6['_meta'],
      'options': v6['options'],
      'entities': entities.take(count).toList(),
      if (fixedSql != null) 'fixed_sql': fixedSql.take(count).toList(),
    };

    final out = File('${schemaDir.path}/drift_schema_v$version.json');
    out.writeAsStringSync('${encoder.convert(snapshot)}\n');
    stdout.writeln('wrote ${out.path}');
  }

  stdout.writeln('regenerated drift_schema_v1..v5.json from the v6 anchor');

  // v6 (anchor) and v7+ (ALTER versions) must be their own real dumps.
  for (final version in _dumpedVersions) {
    final f = File('${schemaDir.path}/drift_schema_v$version.json');
    if (!f.existsSync()) {
      stderr.writeln(
        'missing drift_schemas/drift_schema_v$version.json — after bumping '
        'schemaVersion, run `dart run drift_dev schema dump '
        'lib/src/db/app_database.dart drift_schemas/` before this script',
      );
      exit(2);
    }
    if (version >= 7) {
      final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final tables = (doc['entities'] as List)
          .map((e) => (e as Map<String, dynamic>)['data'])
          .whereType<Map<String, dynamic>>()
          .map((d) => d['name'])
          .toSet();
      if (!tables.contains('bbt_entries') || !tables.contains('daily_flows')) {
        stderr.writeln(
          'drift_schema_v$version.json is missing expected tables — re-dump it',
        );
        exit(2);
      }
      final flows = (doc['entities'] as List)
          .map((e) => (e as Map<String, dynamic>)['data'])
          .whereType<Map<String, dynamic>>()
          .firstWhere((d) => d['name'] == 'daily_flows');
      final columns = (flows['columns'] as List? ?? const [])
          .map((c) => (c as Map<String, dynamic>)['name'])
          .toSet();
      if (!columns.contains('source') || !columns.contains('external_id')) {
        stderr.writeln(
          'drift_schema_v$version.json does not carry the v7 provenance '
          'columns — did you re-dump after bumping schemaVersion?',
        );
        exit(2);
      }
    }
    stdout.writeln('checked ${f.path} (real dump)');
  }
}
