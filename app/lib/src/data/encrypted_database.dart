import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart' as sqlite_open;
import 'package:sqlite3/sqlite3.dart';

/// Opens the [AppDatabase] backed by an **encrypted** SQLCipher file.
///
/// Fail-safe rules (p0.4 acceptance criteria):
///  * If no key is stored and a database file already exists, throw
///    [MissingDatabaseKeyException] — never replace it with a fresh/unkeyed one.
///  * If SQLCipher is not actually active, throw rather than write plaintext.
class EncryptedDatabase {
  const EncryptedDatabase._();

  static const _fileName = 'olf.db';

  /// Open (creating on first run) the encrypted database file [fileName] in
  /// [directory], using the key from [keyStore]. Generates and stores a fresh
  /// 256-bit key the first time only. [fileName] defaults to the real database;
  /// the decoy vault (p2.2) passes its own name so the two files never collide.
  static Future<AppDatabase> open({
    required DatabaseKeyStore keyStore,
    required Directory directory,
    String fileName = _fileName,
  }) async {
    final file = File(p.join(directory.path, fileName));

    var key = await keyStore.read();
    if (key == null) {
      if (file.existsSync()) {
        throw const MissingDatabaseKeyException();
      }
      key = _generateKey();
      await keyStore.write(key);
    }

    return AppDatabase(_openExecutor(file, key));
  }

  static String _generateKey() {
    final rng = Random.secure();
    return base64.encode(List<int>.generate(32, (_) => rng.nextInt(256)));
  }

  static QueryExecutor _openExecutor(File file, String key) {
    return LazyDatabase(() async {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
        sqlite_open.open.overrideFor(
          sqlite_open.OperatingSystem.android,
          openCipherOnAndroid,
        );
      }

      file.parent.createSync(recursive: true);
      final raw = sqlite3.open(file.path);

      // Key must be the first statement on the connection.
      raw.execute("PRAGMA key = '${key.replaceAll("'", "''")}';");

      // A plain sqlite3 would silently ignore PRAGMA key and write plaintext.
      if (raw.select('PRAGMA cipher_version;').isEmpty) {
        raw.dispose();
        throw StateError(
          'SQLCipher is not active — refusing to open an unencrypted database.',
        );
      }

      // Forces the key to be verified against the file (wrong key throws here).
      raw.execute('SELECT count(*) FROM sqlite_master;');

      return NativeDatabase.opened(raw);
    });
  }
}
