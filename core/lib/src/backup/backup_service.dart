import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'backup_document.dart';

/// Reads every row of the local database into a [BackupDocument], and restores
/// one back (p1.10).
///
/// The copy is row-level and untyped — `SELECT *` out, parameterised `INSERT`
/// back — so "reproduces all data exactly" holds by construction: raw SQLite
/// values (`int` / `double` / `String` / `bool` / `null`) make the round trip
/// untouched, including the integer timestamps drift stores for `DateTime`
/// columns and the string names it stores for enum columns.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Every table, **parents before children**, so this order is safe to insert
  /// in and its reverse is safe to delete in (the one foreign key is
  /// `daily_symptom_entries.symptom_type_id -> symptom_types.id`). A test
  /// asserts this list matches the schema, so adding a table fails loudly here.
  static const List<String> tableOrder = [
    'cycle_events',
    'periods',
    'daily_flows',
    'symptom_types',
    'daily_symptom_entries',
    'bbt_entries',
    'cervical_mucus_entries',
    'app_settings',
    'medications',
    'birth_control_entries',
    'reminders',
  ];

  /// Snapshot the whole database.
  Future<BackupDocument> export() async {
    final tables = <String, BackupTable>{};
    for (final name in tableOrder) {
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      tables[name] = [for (final row in rows) Map.of(row.data)];
    }
    return BackupDocument(
      formatVersion: backupFormatVersion,
      appSchemaVersion: _db.schemaVersion,
      createdAt: DateTime.now().toUtc(),
      tables: tables,
    );
  }

  /// Replace the entire database contents with [doc].
  ///
  /// All-or-nothing: the wipe and every insert run in one transaction, so a
  /// failure part-way leaves the existing data intact. Streams are refreshed
  /// afterwards so open screens rebuild.
  ///
  /// v1 only accepts a backup whose [BackupDocument.appSchemaVersion] matches
  /// this build's `schemaVersion`; a mismatch throws [BackupFormatException]
  /// rather than risk a lossy restore. (A future version can migrate instead.)
  Future<void> import(BackupDocument doc) async {
    if (doc.appSchemaVersion != _db.schemaVersion) {
      throw BackupFormatException(
        'This backup is from a different version of olf (database '
        'v${doc.appSchemaVersion}, this app uses v${_db.schemaVersion}). '
        'Restoring it here could lose or corrupt data.',
      );
    }
    final unknown = doc.tables.keys.toSet().difference(tableOrder.toSet());
    if (unknown.isNotEmpty) {
      throw BackupFormatException(
        'The backup has data this app does not recognise (${unknown.join(', ')}).',
      );
    }

    await _db.transaction(() async {
      for (final name in tableOrder.reversed) {
        await _db.customStatement('DELETE FROM "$name"');
      }
      for (final name in tableOrder) {
        for (final row in doc.tables[name] ?? const <Map<String, Object?>>[]) {
          if (row.isEmpty) continue;
          final columns = row.keys.toList();
          final quoted = columns.map((c) => '"$c"').join(', ');
          final placeholders = List.filled(columns.length, '?').join(', ');
          await _db.customStatement(
            'INSERT INTO "$name" ($quoted) VALUES ($placeholders)',
            [for (final c in columns) row[c]],
          );
        }
      }
    });

    _db.notifyUpdates({
      for (final table in _db.allTables)
        TableUpdate.onTable(table, kind: UpdateKind.update),
    });
  }
}
