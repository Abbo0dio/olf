/// Local app-unlock PIN: validation, hashing and verification (p1.8).
///
/// **Scope.** This is a UI-level gate, not a cryptographic boundary. The
/// database is already encrypted at rest with a key held in the platform secure
/// enclave; the PIN does not derive or wrap that key in Phase 1. Binding the DB
/// key to the PIN (and biometric unlock, a decoy PIN, scheduled deletion) is
/// Phase 2 — see `DEVELOPMENT_PLAN.md` §7 / §9.
///
/// The PIN is never stored. What is stored (in the platform secure store, via a
/// [PinStore]) is a [PinCredential]: a random salt, an iteration count, and the
/// iterated-HMAC-SHA256 hash of the PIN. Verification recomputes the hash and
/// compares in constant time.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Shortest / longest PIN we accept. Digits only.
const int minPinLength = 4;
const int maxPinLength = 12;

/// Default work factor for [hashPin]. Iterated HMAC-SHA256 (a small PBKDF2 by
/// hand) — a four-digit PIN has only 10k values, so the work factor is what buys
/// any resistance to an attacker who has exfiltrated the secure store.
///
/// Kept modest so an on-device unlock stays snappy on the main isolate (~150 ms
/// desktop, well under a second on a mid phone). Phase 2 should move hashing to
/// a background isolate and raise this — or better, bind the database key to the
/// PIN with a real KDF (see `DEVELOPMENT_PLAN.md` §9).
const int defaultPinIterations = 30000;

/// Why a candidate PIN was rejected. `null` from [validatePin] means it is
/// acceptable.
enum PinError {
  /// Fewer than [minPinLength] characters.
  tooShort,

  /// More than [maxPinLength] characters.
  tooLong,

  /// Contains something other than the digits 0–9.
  notNumeric,
}

/// A short, neutral sentence suitable for showing the user.
extension PinErrorMessage on PinError {
  String describe() => switch (this) {
    PinError.tooShort => 'Use at least $minPinLength digits.',
    PinError.tooLong => 'Use at most $maxPinLength digits.',
    PinError.notNumeric => 'Use digits only.',
  };
}

/// Thrown by PIN setup when the value fails [validatePin].
class PinException implements Exception {
  const PinException(this.error);

  final PinError error;

  @override
  String toString() => 'PinException: ${error.describe()}';
}

/// Validate a candidate PIN. Returns the first problem found, or `null` when it
/// is acceptable. Rules, in order: too short, too long, non-numeric.
PinError? validatePin(String pin) {
  if (pin.length < minPinLength) return PinError.tooShort;
  if (pin.length > maxPinLength) return PinError.tooLong;
  for (final unit in pin.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return PinError.notNumeric;
  }
  return null;
}

/// The stored proof of a PIN — safe to persist, useless without the PIN itself.
class PinCredential {
  const PinCredential({
    required this.saltBase64,
    required this.hashBase64,
    required this.iterations,
  });

  /// Rebuild from [toStorageString]. Throws [FormatException] on malformed input.
  factory PinCredential.fromStorageString(String value) {
    final map = jsonDecode(value);
    if (map is! Map ||
        map['v'] != 1 ||
        map['salt'] is! String ||
        map['hash'] is! String ||
        map['iter'] is! int) {
      throw const FormatException('Unrecognised PinCredential payload');
    }
    return PinCredential(
      saltBase64: map['salt'] as String,
      hashBase64: map['hash'] as String,
      iterations: map['iter'] as int,
    );
  }

  final String saltBase64;
  final String hashBase64;
  final int iterations;

  /// A single opaque string for the secure store.
  String toStorageString() => jsonEncode(<String, Object>{
    'v': 1,
    'salt': saltBase64,
    'hash': hashBase64,
    'iter': iterations,
  });

  @override
  bool operator ==(Object other) =>
      other is PinCredential &&
      other.saltBase64 == saltBase64 &&
      other.hashBase64 == hashBase64 &&
      other.iterations == iterations;

  @override
  int get hashCode => Object.hash(saltBase64, hashBase64, iterations);
}

/// 16 cryptographically-random bytes, base64. Pass [random] in tests.
String generatePinSalt([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = Uint8List(16);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return base64Encode(bytes);
}

/// Derive a [PinCredential] for [pin] with a fresh salt.
PinCredential derivePinCredential(
  String pin, {
  int iterations = defaultPinIterations,
  Random? random,
}) {
  final salt = generatePinSalt(random);
  return PinCredential(
    saltBase64: salt,
    hashBase64: hashPin(pin, salt, iterations: iterations),
    iterations: iterations,
  );
}

/// Iterated HMAC-SHA256 of [pin] keyed by [saltBase64], returned base64.
///
/// Deterministic for the same inputs — this is what both setup and verification
/// call.
String hashPin(
  String pin,
  String saltBase64, {
  int iterations = defaultPinIterations,
}) {
  final salt = base64Decode(saltBase64);
  final hmac = Hmac(sha256, utf8.encode(pin));
  var acc = hmac.convert(salt).bytes;
  for (var i = 1; i < iterations; i++) {
    acc = hmac.convert(acc).bytes;
  }
  return base64Encode(acc);
}

/// `true` when [pin] matches [credential]. Constant-time in the hash comparison.
bool verifyPin(String pin, PinCredential credential) {
  final candidate = hashPin(
    pin,
    credential.saltBase64,
    iterations: credential.iterations,
  );
  final a = utf8.encode(candidate);
  final b = utf8.encode(credential.hashBase64);
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
