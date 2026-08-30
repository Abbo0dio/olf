import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/backup/backup_controller.dart';
import 'package:olf_core/olf_core.dart';

import 'fake_backup_gateway.dart';

void main() {
  late AppDatabase db;
  late FakeBackupGateway gateway;
  late BackupController controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = FakeBackupGateway();
    controller = BackupController(service: BackupService(db), files: gateway);
  });
  tearDown(() => db.close());

  Future<void> addPeriod() => db
      .into(db.periods)
      .insert(PeriodsCompanion.insert(startDate: DateTime.utc(2026, 3, 1)));

  test('export writes an encrypted file and reports the saved path', () async {
    await addPeriod();
    final result = await controller.export(passphrase: 'passphrase-1');

    expect(result, isA<ExportSaved>());
    expect((result as ExportSaved).path, contains('olf-backup'));
    expect(gateway.file, isNotNull);
    // Encrypted: the column name is not visible in the bytes.
    expect(String.fromCharCodes(gateway.file!), isNot(contains('start_date')));
  });

  test('export → wipe → restore brings the data back', () async {
    await addPeriod();
    await controller.export(passphrase: 'passphrase-1');

    await db.delete(db.periods).go();
    expect(await db.select(db.periods).get(), isEmpty);

    final result = await controller.restore(passphrase: 'passphrase-1');

    expect(result, isA<RestoreDone>());
    final periods = await db.select(db.periods).get();
    expect(periods, hasLength(1));
    expect(periods.single.startDate.toUtc(), DateTime.utc(2026, 3, 1));
  });

  test('restore with the wrong passphrase changes nothing', () async {
    await addPeriod();
    await controller.export(passphrase: 'the-right-one');
    await db.delete(db.periods).go();

    final result = await controller.restore(passphrase: 'the-wrong-one');

    expect(result, isA<RestoreWrongPassphrase>());
    expect(await db.select(db.periods).get(), isEmpty);
  });

  test(
    'export reports cancellation when the save dialog is dismissed',
    () async {
      gateway.savePath = null;
      expect(
        await controller.export(passphrase: 'passphrase-1'),
        isA<ExportCancelled>(),
      );
    },
  );

  test('restore reports cancellation when no file is picked', () async {
    gateway.pickReturnsFile = false;
    expect(
      await controller.restore(passphrase: 'passphrase-1'),
      isA<RestoreCancelled>(),
    );
  });

  test('restore rejects a file that is not a backup', () async {
    gateway.file = Uint8List.fromList(List.filled(64, 42));
    final result = await controller.restore(passphrase: 'passphrase-1');
    expect(result, isA<RestoreBadFile>());
  });

  test('export runs the retention sweep before snapshotting (p2.3)', () async {
    var sweepCalls = 0;
    var rowsAtSweep = -1;
    final withSweep = BackupController(
      service: BackupService(db),
      files: gateway,
      sweepRetention: () async {
        sweepCalls++;
        // The sweep gets to touch the data before the snapshot is taken.
        await db.delete(db.periods).go();
        rowsAtSweep = (await db.select(db.periods).get()).length;
      },
    );

    await addPeriod();
    final result = await withSweep.export(passphrase: 'passphrase-1');

    expect(result, isA<ExportSaved>());
    expect(sweepCalls, 1);
    expect(rowsAtSweep, 0);
    // Restoring the file it wrote brings back an empty periods table.
    await addPeriod();
    await withSweep.restore(passphrase: 'passphrase-1');
    expect(await db.select(db.periods).get(), isEmpty);
  });

  test('a null sweepRetention hook is simply skipped', () async {
    await addPeriod();
    final result = await controller.export(passphrase: 'passphrase-1');
    expect(result, isA<ExportSaved>());
  });
}
