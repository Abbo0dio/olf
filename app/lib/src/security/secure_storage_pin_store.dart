import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:olf_core/olf_core.dart';

/// Secure-storage key for the real app-unlock PIN credential (p1.8).
const String realPinCredentialKey = 'olf.pin.credential.v1';

/// Secure-storage key for the decoy / duress PIN credential (p2.2). A separate
/// entry so the two credentials never share storage.
const String decoyPinCredentialKey = 'olf.pin.decoy.credential.v1';

/// [PinStore] backed by the platform secure enclave — iOS Keychain and Android
/// Keystore (`EncryptedSharedPreferences`) — via `flutter_secure_storage`.
///
/// Mirrors `SecureStorageKeyStore`: the PIN credential never touches plaintext
/// storage or app preferences. [keyName] selects which credential this store
/// owns ([realPinCredentialKey] by default, [decoyPinCredentialKey] for the
/// decoy PIN).
class SecureStoragePinStore implements PinStore {
  SecureStoragePinStore({
    FlutterSecureStorage? storage,
    this.keyName = realPinCredentialKey,
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
  Future<PinCredential?> read() async {
    final raw = await _storage.read(
      key: keyName,
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
    key: keyName,
    value: credential.toStorageString(),
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  @override
  Future<void> delete() => _storage.delete(
    key: keyName,
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );
}
