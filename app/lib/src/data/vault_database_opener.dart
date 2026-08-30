import 'package:olf_core/olf_core.dart';
import 'package:path_provider/path_provider.dart';

import 'encrypted_database.dart';
import 'secure_storage_key_store.dart';

/// Which data vault the app is currently showing (p2.2 — decoy / duress PIN).
///
/// [real] is the default and the only one reachable with the real PIN or a
/// biometric unlock. [decoy] is opened only when the decoy PIN is entered at the
/// lock screen; it is a physically separate, separately-keyed database that
/// starts empty. The app never holds both open at once, and backgrounding the
/// app resets this to [real].
enum AppVault { real, decoy }

/// Seam for opening the [AppDatabase] behind a given [AppVault]. Overridden in
/// widget tests so no real SQLCipher file is touched.
abstract interface class VaultDatabaseOpener {
  Future<AppDatabase> open(AppVault vault);
}

/// Production opener: real vs decoy map to different encrypted files and
/// different secure-storage keys under the app support directory.
class EncryptedVaultDatabaseOpener implements VaultDatabaseOpener {
  const EncryptedVaultDatabaseOpener();

  @override
  Future<AppDatabase> open(AppVault vault) async {
    final directory = await getApplicationSupportDirectory();
    return switch (vault) {
      AppVault.real => EncryptedDatabase.open(
        keyStore: SecureStorageKeyStore(),
        directory: directory,
      ),
      AppVault.decoy => EncryptedDatabase.open(
        keyStore: SecureStorageKeyStore(keyName: decoyDatabaseKeyName),
        directory: directory,
        fileName: 'olf-decoy.db',
      ),
    };
  }
}
