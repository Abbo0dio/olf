import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_document.dart';

/// The smallest passphrase [validateBackupPassphrase] will accept.
const int minBackupPassphraseLength = 8;

/// PBKDF2 work factor for a backup passphrase. Higher than the app-lock PIN's
/// (this runs once per export/import, not on every app open); a stored
/// parameter, so a future backup can raise it without breaking old files.
const int backupKdfIterations = 210000;

/// Magic prefix — bytes 0..5 of every sealed backup. The trailing digit is the
/// container version (independent of [backupFormatVersion], which lives in the
/// encrypted document).
const String _containerMagic = 'OLFBK1';

const int _saltLength = 16;
const int _nonceLength = 12; // AES-GCM standard.

/// Why a passphrase was rejected before it was even used.
enum BackupPassphraseError {
  /// Shorter than [minBackupPassphraseLength].
  tooShort,
}

extension BackupPassphraseErrorMessage on BackupPassphraseError {
  String describe() => switch (this) {
    BackupPassphraseError.tooShort =>
      'Use at least $minBackupPassphraseLength characters.',
  };
}

/// `null` if [passphrase] is allowed as a backup passphrase.
BackupPassphraseError? validateBackupPassphrase(String passphrase) {
  if (passphrase.length < minBackupPassphraseLength) {
    return BackupPassphraseError.tooShort;
  }
  return null;
}

/// Thrown by [BackupCipher.open] when the passphrase does not match (or the
/// ciphertext has been tampered with) — the AES-GCM tag fails to verify.
/// Distinct from [BackupFormatException] so the UI can tell the user which of
/// "wrong passphrase" and "not a valid backup file" happened.
class BackupPassphraseException implements Exception {
  const BackupPassphraseException([
    this.message =
        'That passphrase did not work. Check it and try again — the file may '
        'also be damaged.',
  ]);

  final String message;

  @override
  String toString() => 'BackupPassphraseException: $message';
}

/// Encrypts a [BackupDocument] to the single file the user keeps, and back.
///
/// Container: `OLFBK1` magic, a 4-byte big-endian header length, a JSON header
/// (KDF + salt + nonce + GCM tag, all public), then the AES-256-GCM ciphertext
/// of the UTF-8 JSON document. Key = PBKDF2-HMAC-SHA256(passphrase, salt).
class BackupCipher {
  const BackupCipher._();

  static final _aes = AesGcm.with256bits();

  /// Encrypt [doc] under [passphrase]. [random] and [iterations] are injectable
  /// for tests; leave them at their defaults in the app.
  static Future<Uint8List> seal(
    BackupDocument doc,
    String passphrase, {
    int iterations = backupKdfIterations,
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final salt = _randomBytes(_saltLength, rng);
    final nonce = _randomBytes(_nonceLength, rng);
    final key = await _deriveKey(passphrase, salt, iterations);

    final plaintext = utf8.encode(jsonEncode(doc.toJson()));
    final box = await _aes.encrypt(plaintext, secretKey: key, nonce: nonce);

    final header = utf8.encode(
      jsonEncode({
        'kdf': 'pbkdf2-hmac-sha256',
        'iterations': iterations,
        'salt': base64.encode(salt),
        'cipher': 'aes-256-gcm',
        'nonce': base64.encode(nonce),
        'mac': base64.encode(box.mac.bytes),
      }),
    );

    final out = BytesBuilder()
      ..add(ascii.encode(_containerMagic))
      ..add(_uint32be(header.length))
      ..add(header)
      ..add(box.cipherText);
    return out.toBytes();
  }

  /// Decrypt bytes produced by [seal]. Throws [BackupFormatException] if the
  /// framing is wrong and [BackupPassphraseException] if [passphrase] does not
  /// match.
  static Future<BackupDocument> open(List<int> bytes, String passphrase) async {
    final data = Uint8List.fromList(bytes);
    final magicLength = _containerMagic.length;
    if (data.length < magicLength + 4 ||
        ascii.decode(data.sublist(0, magicLength), allowInvalid: true) !=
            _containerMagic) {
      throw const BackupFormatException('This file is not an olf backup.');
    }

    final headerLength = ByteData.sublistView(
      data,
      magicLength,
      magicLength + 4,
    ).getUint32(0, Endian.big);
    final headerStart = magicLength + 4;
    final headerEnd = headerStart + headerLength;
    if (headerLength <= 0 || headerEnd > data.length) {
      throw const BackupFormatException('The backup file is truncated.');
    }

    final Map<String, Object?> header;
    try {
      header =
          jsonDecode(utf8.decode(data.sublist(headerStart, headerEnd)))
              as Map<String, Object?>;
    } catch (_) {
      throw const BackupFormatException('The backup header is unreadable.');
    }

    final salt = _decodeField(header, 'salt');
    final nonce = _decodeField(header, 'nonce');
    final mac = _decodeField(header, 'mac');
    final iterations = header['iterations'];
    if (iterations is! int || iterations <= 0) {
      throw const BackupFormatException('The backup header is incomplete.');
    }

    final key = await _deriveKey(passphrase, salt, iterations);
    final box = SecretBox(data.sublist(headerEnd), nonce: nonce, mac: Mac(mac));

    final List<int> plaintext;
    try {
      plaintext = await _aes.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const BackupPassphraseException();
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plaintext));
    } catch (_) {
      throw const BackupFormatException('The backup contents are unreadable.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException('The backup contents are unreadable.');
    }
    return BackupDocument.fromJson(decoded);
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static Uint8List _decodeField(Map<String, Object?> header, String key) {
    final value = header[key];
    if (value is! String) {
      throw const BackupFormatException('The backup header is incomplete.');
    }
    try {
      return base64.decode(value);
    } catch (_) {
      throw const BackupFormatException('The backup header is corrupt.');
    }
  }
}

Uint8List _randomBytes(int length, Random rng) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = rng.nextInt(256);
  }
  return out;
}

Uint8List _uint32be(int value) {
  final out = Uint8List(4);
  ByteData.sublistView(out).setUint32(0, value, Endian.big);
  return out;
}
