import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'settings_repository.dart';

/// [SettingsRepository] backed by the drift [AppDatabase].
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {DateTime Function() now = DateTime.now})
    : _now = now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Stream<String?> watch(String key) {
    return (_db.select(_db.appSettings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  @override
  Future<void> set(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(_now()),
          ),
        );
  }

  @override
  Future<void> remove(String key) async {
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
  }
}
