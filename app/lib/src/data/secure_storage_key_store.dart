import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:olf_core/olf_core.dart';

/// [DatabaseKeyStore] backed by the platform secure enclave — iOS Keychain and
/// Android Keystore (`EncryptedSharedPreferences`) — via `flutter_secure_storage`.
///
/// The database key never touches plaintext storage or app preferences.
class SecureStorageKeyStore implements DatabaseKeyStore {
  SecureStorageKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'olf.db.key.v1';

  final FlutterSecureStorage _storage;

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<String?> read() => _storage.read(
    key: _keyName,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  @override
  Future<void> write(String keyBase64) => _storage.write(
    key: _keyName,
    value: keyBase64,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
