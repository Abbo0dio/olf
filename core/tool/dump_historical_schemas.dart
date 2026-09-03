// Regenerates the historical drift schema snapshots in `core/drift_schemas/`.
//
// We adopted drift's `schema dump` tooling at schema v6 (p5.6), so there is no
// historical record of v1..v5 to dump from source. This script reconstructs
// them from the v6 snapshot.
//
// It is sound because olf's migration history is **strictly additive**: every
// `onUpgrade` block in `lib/src/db/app_database.dart` only `createTable`s and
// never alters an existing table (p1.11's pregnancy markers reuse the
// `cycle_events.type` TEXT column with no DDL change). So schema vN is exactly
// the first N "waves" of tables from the v6 snapshot, each table byte-identical
// to its v6 form — full Dart metadata (type converters, `dateTime` mapping)
// preserved, which a dump from a bare `.db` file would lose.
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
// Adding a schema v7: bump `schemaVersion`, add the `onUpgrade` block, re-run
// both commands (the dump refreshes v6→v7; this script then rebuilds v1..v6),
// and extend `test/db/migration_matrix_test.dart`.

import 'dart:convert';
import 'dart:io';

/// Number of tables present at each historical schema version.
const Map<int, int> _tableCountAtVersion = {1: 1, 2: 2, 3: 3, 4: 5, 5: 8};

void main() {
  final schemaDir = Directory('drift_schemas');
  final latest = File('${schemaDir.path}/drift_schema_v6.json');
  if (!latest.existsSync()) {
    stderr.writeln(
      'run `dart run drift_dev schema dump lib/src/db/app_database.dart '
      'drift_schemas/` first',
    );
    exit(2);
  }

  final v6 = jsonDecode(latest.readAsStringSync()) as Map<String, dynamic>;
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

  stdout.writeln('regenerated drift_schema_v1..v5.json from v6');
}
