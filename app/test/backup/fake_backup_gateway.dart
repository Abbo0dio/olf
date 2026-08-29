import 'dart:typed_data';

import 'package:olf_app/src/backup/backup_gateway.dart';

/// In-memory [BackupFileGateway] — the "file" is just a field. Lets the backup
/// flow be tested without the `file_picker` platform channel.
class FakeBackupGateway implements BackupFileGateway {
  FakeBackupGateway({this.pickName = 'olf-backup.olfbackup'});

  /// The last bytes written by [writeBackup]; also what [pickBackup] returns.
  Uint8List? file;

  /// Set to `null` to simulate the user cancelling the save dialog.
  String? savePath = '/fake/Downloads/olf-backup.olfbackup';

  /// Set to `false` to simulate the user cancelling the open dialog.
  bool pickReturnsFile = true;

  String pickName;

  int writeCount = 0;
  int pickCount = 0;

  @override
  Future<String?> writeBackup(
    Uint8List bytes, {
    required String suggestedName,
  }) async {
    writeCount++;
    file = bytes;
    return savePath;
  }

  @override
  Future<PickedBackup?> pickBackup() async {
    pickCount++;
    final bytes = file;
    if (!pickReturnsFile || bytes == null) return null;
    return PickedBackup(name: pickName, bytes: bytes);
  }
}
