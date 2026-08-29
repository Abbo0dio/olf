import 'package:olf_core/olf_core.dart';

import 'backup_gateway.dart';

/// Outcome of an export attempt.
sealed class ExportResult {
  const ExportResult();
}

/// The encrypted file was written to [path].
class ExportSaved extends ExportResult {
  const ExportSaved(this.path);
  final String path;
}

/// The user dismissed the save dialog.
class ExportCancelled extends ExportResult {
  const ExportCancelled();
}

/// Outcome of a restore attempt.
sealed class RestoreResult {
  const RestoreResult();
}

/// [rowCount] rows across every table were restored.
class RestoreDone extends RestoreResult {
  const RestoreDone(this.rowCount);
  final int rowCount;
}

/// The user dismissed the file picker.
class RestoreCancelled extends RestoreResult {
  const RestoreCancelled();
}

/// The passphrase did not match the chosen file.
class RestoreWrongPassphrase extends RestoreResult {
  const RestoreWrongPassphrase();
}

/// The chosen file is not a backup this build can restore. [message] is safe to
/// show the user.
class RestoreBadFile extends RestoreResult {
  const RestoreBadFile(this.message);
  final String message;
}

/// Drives export / restore: talk to [BackupService] for the data, [BackupCipher]
/// for the encryption, and a [BackupFileGateway] for the one file-system touch.
///
/// Every failure that can reasonably happen (cancel, wrong passphrase, wrong
/// file) comes back as a [RestoreResult] / [ExportResult] value; only genuine
/// bugs throw.
class BackupController {
  BackupController({
    required BackupService service,
    required BackupFileGateway files,
  }) : _service = service,
       _files = files;

  final BackupService _service;
  final BackupFileGateway _files;

  /// Snapshot the database, encrypt it under [passphrase], and hand it to the
  /// save dialog. [passphrase] must already have passed
  /// [validateBackupPassphrase].
  Future<ExportResult> export({required String passphrase}) async {
    final document = await _service.export();
    final bytes = await BackupCipher.seal(document, passphrase);
    final path = await _files.writeBackup(
      bytes,
      suggestedName: _suggestedFileName(document.createdAt),
    );
    return path == null ? const ExportCancelled() : ExportSaved(path);
  }

  /// Ask the user for a file, decrypt it with [passphrase], and replace the
  /// database contents with it.
  Future<RestoreResult> restore({required String passphrase}) async {
    final picked = await _files.pickBackup();
    if (picked == null) return const RestoreCancelled();

    final BackupDocument document;
    try {
      document = await BackupCipher.open(picked.bytes, passphrase);
    } on BackupPassphraseException {
      return const RestoreWrongPassphrase();
    } on BackupFormatException catch (e) {
      return RestoreBadFile(e.message);
    } on FormatException {
      return const RestoreBadFile('This file is not an olf backup.');
    }

    try {
      await _service.import(document);
    } on BackupFormatException catch (e) {
      return RestoreBadFile(e.message);
    }
    return RestoreDone(document.rowCount);
  }

  static String _suggestedFileName(DateTime createdAt) {
    final d = createdAt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'olf-backup-${d.year}-${two(d.month)}-${two(d.day)}.olfbackup';
  }
}
