/// The versioned, still-plaintext shape of a local backup (p1.10).
///
/// [BackupService] fills one of these from the database; [BackupCipher] wraps it
/// in an encrypted container for the file the user keeps. Keeping the document
/// and the encryption separate means the format can be unit-tested — and
/// migrated across versions — without touching crypto.
library;

/// Identifies the file as an olf backup. Present verbatim in every document.
const String backupFormatId = 'olf.backup';

/// The document schema version. Bump when the JSON layout changes in a way an
/// older build could not read, and add a forward-migration branch in
/// [BackupDocument.fromJson]. This is **not** the database `schemaVersion` —
/// that travels alongside as [BackupDocument.appSchemaVersion].
const int backupFormatVersion = 1;

/// Thrown when bytes handed to the reader are not a backup this build can load:
/// wrong magic / `format`, a missing or non-integer version, or a version newer
/// than [backupFormatVersion]. A wrong passphrase is a
/// [BackupPassphraseException] instead — the two are deliberately distinct so
/// the UI can say "not an olf backup" versus "wrong passphrase".
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// One table's rows, each a `column name -> raw SQLite value` map (only
/// `int` / `double` / `String` / `bool` / `null` ever appear).
typedef BackupTable = List<Map<String, Object?>>;

/// A whole backup, decoded and validated but not yet applied.
class BackupDocument {
  const BackupDocument({
    required this.formatVersion,
    required this.appSchemaVersion,
    required this.createdAt,
    required this.tables,
  });

  /// [backupFormatVersion] at the time of writing.
  final int formatVersion;

  /// The database `schemaVersion` the backup was taken from. Carried so a
  /// restore onto a newer app can tell "same schema" from "needs handling";
  /// v1 only ever restores same-schema backups (see [BackupService.import]).
  final int appSchemaVersion;

  /// When the backup was taken (UTC).
  final DateTime createdAt;

  /// Table name -> rows. Order is the writer's; [BackupService] controls the
  /// order rows are re-inserted in.
  final Map<String, BackupTable> tables;

  /// Total rows across every table — handy for a "restored N entries" message.
  int get rowCount => tables.values.fold(0, (sum, rows) => sum + rows.length);

  Map<String, Object?> toJson() => {
    'format': backupFormatId,
    'formatVersion': formatVersion,
    'appSchemaVersion': appSchemaVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'tables': tables,
  };

  /// Parse and validate a decoded JSON map. Throws [BackupFormatException] on
  /// anything this build cannot faithfully restore.
  factory BackupDocument.fromJson(Map<String, Object?> json) {
    if (json['format'] != backupFormatId) {
      throw const BackupFormatException('This file is not an olf backup.');
    }
    final version = json['formatVersion'];
    if (version is! int) {
      throw const BackupFormatException(
        'The backup is missing its format version.',
      );
    }
    if (version > backupFormatVersion) {
      throw BackupFormatException(
        'This backup was made by a newer version of olf (backup format '
        'v$version). Update olf, then restore it.',
      );
    }
    // version < backupFormatVersion: apply forward migrations here as the
    // format evolves. v1 is the only version so far, so there is nothing to do.

    final schema = json['appSchemaVersion'];
    if (schema is! int) {
      throw const BackupFormatException(
        'The backup is missing its database version.',
      );
    }

    final rawCreatedAt = json['createdAt'];
    final createdAt = rawCreatedAt is String
        ? DateTime.tryParse(rawCreatedAt)?.toUtc()
        : null;
    if (createdAt == null) {
      throw const BackupFormatException(
        'The backup has no readable creation date.',
      );
    }

    final rawTables = json['tables'];
    if (rawTables is! Map) {
      throw const BackupFormatException('The backup has no table data.');
    }
    final tables = <String, BackupTable>{};
    rawTables.forEach((key, value) {
      if (value is! List) {
        throw BackupFormatException('Table "$key" is malformed.');
      }
      tables['$key'] = [
        for (final row in value)
          if (row is Map)
            row.map((k, v) => MapEntry('$k', v))
          else
            throw BackupFormatException('Table "$key" has a malformed row.'),
      ];
    });

    return BackupDocument(
      formatVersion: version,
      appSchemaVersion: schema,
      createdAt: createdAt,
      tables: tables,
    );
  }
}
