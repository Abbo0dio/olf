import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  BackupDocument sample() => BackupDocument(
    formatVersion: backupFormatVersion,
    appSchemaVersion: 6,
    createdAt: DateTime.utc(2026, 8, 29, 12, 30),
    tables: {
      'periods': [
        {'id': 1, 'start_date': 1724930000, 'end_date': null},
      ],
      'app_settings': const [],
    },
  );

  test('toJson / fromJson round-trips', () {
    final doc = sample();
    final restored = BackupDocument.fromJson(doc.toJson());

    expect(restored.formatVersion, doc.formatVersion);
    expect(restored.appSchemaVersion, 6);
    expect(restored.createdAt, DateTime.utc(2026, 8, 29, 12, 30));
    expect(restored.tables['periods'], [
      {'id': 1, 'start_date': 1724930000, 'end_date': null},
    ]);
    expect(restored.tables['app_settings'], isEmpty);
    expect(restored.rowCount, 1);
  });

  test('rejects a file that is not an olf backup', () {
    final json = sample().toJson()..['format'] = 'something.else';
    expect(
      () => BackupDocument.fromJson(json),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('not an olf backup'),
        ),
      ),
    );
  });

  test('rejects a missing / non-integer format version', () {
    final json = sample().toJson()..remove('formatVersion');
    expect(
      () => BackupDocument.fromJson(json),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects a backup newer than this build can read', () {
    final json = sample().toJson()..['formatVersion'] = backupFormatVersion + 1;
    expect(
      () => BackupDocument.fromJson(json),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('newer version of olf'),
        ),
      ),
    );
  });

  test('an older format version is still accepted (forward-compatible)', () {
    // No v0 exists yet, but the parser must not hard-fail on version < current
    // once one does — it should fall through to the (currently empty) migration
    // path. Simulate by asking for version 1 explicitly against a future build.
    final json = sample().toJson()..['formatVersion'] = 1;
    expect(BackupDocument.fromJson(json).formatVersion, 1);
  });

  test('rejects malformed table data', () {
    final json = sample().toJson()..['tables'] = {'periods': 'not-a-list'};
    expect(
      () => BackupDocument.fromJson(json),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects an unreadable creation date', () {
    final json = sample().toJson()..['createdAt'] = 'whenever';
    expect(
      () => BackupDocument.fromJson(json),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
