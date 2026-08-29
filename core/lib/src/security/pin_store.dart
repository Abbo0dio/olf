import 'pin.dart';

/// Persists the [PinCredential] for the local app-unlock PIN (p1.8).
///
/// Like [DatabaseKeyStore], the implementation lives in the platform layer
/// (`flutter_secure_storage` → iOS Keychain / Android Keystore in the app);
/// `core` only defines the contract. Presence of a credential **is** the
/// "a PIN is set" signal — there is no separate flag.
abstract interface class PinStore {
  /// The stored credential, or `null` if no PIN has been set.
  Future<PinCredential?> read();

  /// Persist [credential], replacing any existing one.
  Future<void> write(PinCredential credential);

  /// Remove the credential — turning the PIN lock off.
  Future<void> delete();
}
