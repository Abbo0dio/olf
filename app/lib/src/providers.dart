import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';
import 'package:path_provider/path_provider.dart';

import 'data/encrypted_database.dart';
import 'data/secure_storage_key_store.dart';

/// Platform secure storage for the database encryption key.
final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => SecureStorageKeyStore(),
);

/// The opened, encrypted [AppDatabase].
///
/// `loading` while it opens, `error` (typically [MissingDatabaseKeyException])
/// when it can't — the UI turns that into a fail-safe screen instead of data.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final directory = await getApplicationSupportDirectory();
  final db = await EncryptedDatabase.open(
    keyStore: ref.watch(databaseKeyStoreProvider),
    directory: directory,
  );
  ref.onDispose(db.close);
  return db;
});

/// Repository over the opened database. Reading this before [appDatabaseProvider]
/// has resolved throws — the UI only builds dependents inside its `data` branch.
final cycleEventRepositoryProvider = Provider<CycleEventRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return DriftCycleEventRepository(db);
});

/// The most recent `periodStart`, live. Not `autoDispose` — the home screen
/// always listens, and disposing mid-frame leaves a drift stream-close timer
/// pending (which trips widget tests).
final mostRecentPeriodStartProvider = StreamProvider<CycleEvent?>((ref) {
  return ref.watch(cycleEventRepositoryProvider).watchMostRecentPeriodStart();
});
