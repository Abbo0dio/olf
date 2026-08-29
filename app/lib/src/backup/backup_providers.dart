import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import 'backup_controller.dart';
import 'backup_gateway.dart';

/// The platform file-dialog seam. Overridden in tests with an in-memory fake.
final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const FilePickerBackupFileGateway(),
);

/// Export / restore driver. Only valid inside the database `data` branch (the
/// backup screen is reached from Settings, which is reached from the home
/// screen, which only renders once the database is open).
final backupControllerProvider = Provider<BackupController>((ref) {
  final db = ref.watch(appDatabaseProvider).requireValue;
  return BackupController(
    service: BackupService(db),
    files: ref.watch(backupFileGatewayProvider),
  );
});
