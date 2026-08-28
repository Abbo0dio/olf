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

// Period CRUD lives in `period/period_providers.dart`. `CycleEventRepository`
// in olf_core is retained for the point-in-time markers p1.11 adds (loss,
// birth, postpartum) and is not wired into the app yet.
