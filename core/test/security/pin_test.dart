import 'dart:math';

import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('validatePin', () {
    test('accepts a plain 4–12 digit PIN', () {
      expect(validatePin('1234'), isNull);
      expect(validatePin('000000'), isNull);
      expect(validatePin('123456789012'), isNull);
    });

    test('rejects too short / too long / non-numeric, in that order', () {
      expect(validatePin('123'), PinError.tooShort);
      expect(validatePin('1234567890123'), PinError.tooLong);
      expect(validatePin('12a4'), PinError.notNumeric);
      expect(validatePin('12 4'), PinError.notNumeric);
      // too-short is checked before numeric
      expect(validatePin('1a'), PinError.tooShort);
    });

    test('every error describes itself', () {
      for (final e in PinError.values) {
        expect(e.describe(), isNotEmpty);
      }
    });
  });

  group('hashing', () {
    test('hashPin is deterministic and salt-sensitive', () {
      final a = hashPin('1234', 'c2FsdC1vbmU=', iterations: 200);
      final b = hashPin('1234', 'c2FsdC1vbmU=', iterations: 200);
      final c = hashPin('1234', 'c2FsdC10d28=', iterations: 200);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('iteration count changes the output', () {
      expect(
        hashPin('1234', 'c2FsdC1vbmU=', iterations: 100),
        isNot(hashPin('1234', 'c2FsdC1vbmU=', iterations: 101)),
      );
    });

    test('generatePinSalt is 16 bytes, base64, and varies', () {
      final s1 = generatePinSalt();
      final s2 = generatePinSalt();
      expect(s1, isNot(s2));
      // 16 bytes → 24 base64 chars incl. padding
      expect(s1.length, 24);
    });

    test('deterministic salt via injected Random', () {
      final cred1 = derivePinCredential(
        '4321',
        iterations: 200,
        random: Random(7),
      );
      final cred2 = derivePinCredential(
        '4321',
        iterations: 200,
        random: Random(7),
      );
      expect(cred1, cred2);
    });
  });

  group('verifyPin', () {
    late PinCredential cred;
    setUp(() {
      cred = derivePinCredential('2468', iterations: 300, random: Random(1));
    });

    test('accepts the right PIN, rejects a wrong one', () {
      expect(verifyPin('2468', cred), isTrue);
      expect(verifyPin('2469', cred), isFalse);
      expect(verifyPin('', cred), isFalse);
    });

    test('verification uses the credential\'s own iteration count', () {
      // A credential built at 300 iterations still verifies even though the
      // library default is far higher.
      expect(cred.iterations, 300);
      expect(verifyPin('2468', cred), isTrue);
    });
  });

  group('PinCredential storage round-trip', () {
    test('toStorageString → fromStorageString is lossless', () {
      final cred = derivePinCredential(
        '1357',
        iterations: 250,
        random: Random(3),
      );
      final restored = PinCredential.fromStorageString(cred.toStorageString());
      expect(restored, cred);
      expect(verifyPin('1357', restored), isTrue);
    });

    test('fromStorageString rejects a malformed payload', () {
      expect(
        () => PinCredential.fromStorageString('not json'),
        throwsFormatException,
      );
      expect(
        () => PinCredential.fromStorageString('{"v":2}'),
        throwsFormatException,
      );
    });
  });
}
