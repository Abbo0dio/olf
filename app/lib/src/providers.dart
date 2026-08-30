import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'data/vault_database_opener.dart';

export 'data/vault_database_opener.dart' show AppVault;

/// The vault currently in effect (p2.2). Starts [AppVault.real]; the lock screen
/// flips it to [AppVault.decoy] when the decoy PIN is entered, and `AppGate`
/// resets it to [AppVault.real] whenever the app is backgrounded.
final appVaultProvider = StateProvider<AppVault>((ref) => AppVault.real);

/// How the encrypted database is opened for a vault. Overridden with a fake in
/// widget tests.
final vaultDatabaseOpenerProvider = Provider<VaultDatabaseOpener>(
  (ref) => const EncryptedVaultDatabaseOpener(),
);

/// The opened, encrypted [AppDatabase] for the current [appVaultProvider].
///
/// Rebuilds when the vault changes: the previous database is closed and the new
/// one opened. `loading` while it opens, `error` (typically
/// [MissingDatabaseKeyException]) when it can't — the UI turns that into a
/// fail-safe screen instead of data.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final vault = ref.watch(appVaultProvider);
  final db = await ref.watch(vaultDatabaseOpenerProvider).open(vault);
  ref.onDispose(db.close);
  return db;
});

// Period CRUD lives in `period/period_providers.dart`. `CycleEventRepository`
// in olf_core is retained for the point-in-time markers p1.11 adds (loss,
// birth, postpartum) and is not wired into the app yet.
