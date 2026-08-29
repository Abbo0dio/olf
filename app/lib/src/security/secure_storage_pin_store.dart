import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:olf_core/olf_core.dart';

/// [PinStore] backed by the platform secure enclave — iOS Keychain and Android
/// Keystore (`EncryptedSharedPreferences`) — via `flutter_secure_storage`.
///
/// Mirrors `SecureStorageKeyStore`: the PIN credential never touches plaintext
/// storage or app preferences.
class SecureStoragePinStore implements PinStore {
  SecureStoragePinStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'olf.pin.credential.v1';

  final FlutterSecureStorage _storage;

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<PinCredential?> read() async {
    final raw = await _storage.read(
      key: _keyName,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    if (raw == null) return null;
    try {
      return PinCredential.fromStorageString(raw);
    } on FormatException {
      // A corrupt payload is treated as "no PIN" rather than bricking unlock.
      return null;
    }
  }

  @override
  Future<void> write(PinCredential credential) => _storage.write(
    key: _keyName,
    value: credential.toStorageString(),
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  @override
  Future<void> delete() => _storage.delete(
    key: _keyName,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
