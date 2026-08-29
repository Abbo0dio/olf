import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  // Low iterations keep the KDF fast in tests; the count is stored in the file,
  // so `open` uses whatever `seal` wrote.
  const fastIterations = 500;

  BackupDocument sample() => BackupDocument(
    formatVersion: backupFormatVersion,
    appSchemaVersion: 6,
    createdAt: DateTime.utc(2026, 8, 29),
    tables: {
      'periods': [
        {'id': 1, 'start_date': 1724930000, 'end_date': 1725360000},
        {'id': 2, 'start_date': 1727000000, 'end_date': null},
      ],
      'bbt_entries': [
        {'date': 1724930000, 'temp_celsius': 36.62},
      ],
      'reminders': [
        {'id': 1, 'kind': 'medication', 'hour': 9, 'minute': 0, 'enabled': 1},
      ],
    },
  );

  test(
    'seal then open with the right passphrase restores the document',
    () async {
      final bytes = await BackupCipher.seal(
        sample(),
        'correct horse battery',
        iterations: fastIterations,
        random: Random(1),
      );

      final restored = await BackupCipher.open(bytes, 'correct horse battery');

      expect(restored.appSchemaVersion, 6);
      expect(restored.createdAt, DateTime.utc(2026, 8, 29));
      expect(restored.tables['periods'], sample().tables['periods']);
      expect(restored.tables['bbt_entries']!.single['temp_celsius'], 36.62);
      expect(restored.tables['reminders']!.single['enabled'], 1);
    },
  );

  test('the sealed bytes are an OLFBK1 container, not plaintext', () async {
    final bytes = await BackupCipher.seal(
      sample(),
      'correct horse battery',
      iterations: fastIterations,
      random: Random(2),
    );
    expect(ascii.decode(bytes.sublist(0, 6)), 'OLFBK1');
    // The plaintext contains this; the ciphertext must not.
    expect(
      utf8.decode(bytes, allowMalformed: true),
      isNot(contains('temp_celsius')),
    );
  });

  test('a wrong passphrase throws BackupPassphraseException', () async {
    final bytes = await BackupCipher.seal(
      sample(),
      'the right one',
      iterations: fastIterations,
      random: Random(3),
    );
    expect(
      () => BackupCipher.open(bytes, 'the wrong one'),
      throwsA(isA<BackupPassphraseException>()),
    );
  });

  test(
    'tampered ciphertext throws BackupPassphraseException (GCM tag)',
    () async {
      final bytes = await BackupCipher.seal(
        sample(),
        'the right one',
        iterations: fastIterations,
        random: Random(4),
      );
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 1] ^= 0x01;
      expect(
        () => BackupCipher.open(tampered, 'the right one'),
        throwsA(isA<BackupPassphraseException>()),
      );
    },
  );

  test('random / truncated bytes throw BackupFormatException', () async {
    expect(
      () => BackupCipher.open(
        Uint8List.fromList(List.filled(200, 7)),
        'whatever',
      ),
      throwsA(isA<BackupFormatException>()),
    );

    final bytes = await BackupCipher.seal(
      sample(),
      'the right one',
      iterations: fastIterations,
      random: Random(5),
    );
    expect(
      () => BackupCipher.open(bytes.sublist(0, 20), 'the right one'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  group('validateBackupPassphrase', () {
    test('rejects a short passphrase', () {
      expect(validateBackupPassphrase('short'), BackupPassphraseError.tooShort);
      expect(
        BackupPassphraseError.tooShort.describe(),
        contains('$minBackupPassphraseLength'),
      );
    });

    test('accepts one that is long enough', () {
      expect(validateBackupPassphrase('long enough passphrase'), isNull);
    });
  });
}
