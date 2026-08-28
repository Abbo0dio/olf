/// Stores the symmetric key that encrypts the local database at rest.
///
/// The implementation lives in the platform layer (Keychain / Keystore via
/// `flutter_secure_storage` in the app). `core` only defines the contract so
/// the database wiring and its tests stay platform-agnostic.
abstract interface class DatabaseKeyStore {
  /// The stored key as base64, or `null` if none has ever been written.
  Future<String?> read();

  /// Persist [keyBase64], replacing any existing value.
  Future<void> write(String keyBase64);
}

/// Thrown when an encrypted database file already exists but its key cannot be
/// read.
///
/// The app must **fail safe** on this: surface an error and block all writes,
/// never fall back to creating a fresh (and therefore empty, or unencrypted)
/// database in its place.
class MissingDatabaseKeyException implements Exception {
  const MissingDatabaseKeyException([
    this.message =
        'The database exists but its encryption key is missing or unreadable.',
  ]);

  final String message;

  @override
  String toString() => 'MissingDatabaseKeyException: $message';
}
