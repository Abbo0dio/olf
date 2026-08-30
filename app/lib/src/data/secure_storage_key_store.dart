import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:olf_core/olf_core.dart';

/// Secure-storage key for the real database's encryption key (p0.4).
const String realDatabaseKeyName = 'olf.db.key.v1';

/// Secure-storage key for the decoy database's encryption key (p2.2). Separate
/// entry, separate key material — the decoy vault is cryptographically distinct.
const String decoyDatabaseKeyName = 'olf.db.key.decoy.v1';

/// [DatabaseKeyStore] backed by the platform secure enclave — iOS Keychain and
/// Android Keystore (`EncryptedSharedPreferences`) — via `flutter_secure_storage`.
///
/// The database key never touches plaintext storage or app preferences.
/// [keyName] selects which database's key this store owns.
class SecureStorageKeyStore implements DatabaseKeyStore {
  SecureStorageKeyStore({
    FlutterSecureStorage? storage,
    this.keyName = realDatabaseKeyName,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String keyName;

  final FlutterSecureStorage _storage;

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read() => _storage.read(
    key: keyName,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  @override
  Future<void> write(String keyBase64) => _storage.write(
    key: keyName,
    value: keyBase64,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
