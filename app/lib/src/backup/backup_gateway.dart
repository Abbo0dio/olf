import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A backup file the user chose to restore from.
class PickedBackup {
  const PickedBackup({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// The one place p1.10 touches the platform file system: a system "save as" /
/// "open" dialog. Behind an interface so the backup flow can be widget-tested
/// without the `file_picker` plugin channel (the same pattern p1.7 used for the
/// notification scheduler).
abstract interface class BackupFileGateway {
  /// Show a "save as" dialog seeded with [suggestedName] and write [bytes] to
  /// the chosen location. Returns the saved path, or `null` if the user
  /// cancelled.
  Future<String?> writeBackup(Uint8List bytes, {required String suggestedName});

  /// Show an "open file" dialog. Returns the picked file, or `null` if the user
  /// cancelled.
  Future<PickedBackup?> pickBackup();
}

/// [BackupFileGateway] backed by `file_picker`. No storage permission is
/// required — both dialogs use the platform document picker (SAF on Android,
/// `UIDocumentPicker` on iOS).
class FilePickerBackupFileGateway implements BackupFileGateway {
  const FilePickerBackupFileGateway();

  @override
  Future<String?> writeBackup(
    Uint8List bytes, {
    required String suggestedName,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save your olf backup',
      fileName: suggestedName,
      bytes: bytes,
    );
  }

  @override
  Future<PickedBackup?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose an olf backup file',
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final data = file.bytes;
    if (data == null) return null;
    return PickedBackup(name: file.name, bytes: data);
  }
}
