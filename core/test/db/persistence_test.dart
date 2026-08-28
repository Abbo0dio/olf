import 'dart:io';

import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// The "survive an app restart" round-trip from p0.4, exercised against a real
/// on-disk SQLite file (opened, closed, and re-opened) rather than an emulator.
void main() {
  late Directory tmp;
  late File dbFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('olf_persist_test');
    dbFile = File('${tmp.path}/olf.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<T> withDb<T>(
    Future<T> Function(CycleEventRepository repo) body,
  ) async {
    final db = AppDatabase(NativeDatabase(dbFile));
    try {
      return await body(DriftCycleEventRepository(db));
    } finally {
      await db.close();
    }
  }

  test(
    'logged event persists across a close/reopen and can then be deleted',
    () async {
      final id = await withDb(
        (repo) => repo.logPeriodStart(DateTime(2026, 8, 27)),
      );
      expect(dbFile.existsSync(), isTrue);

      // Reopen: the event is still there.
      final reopened = await withDb((repo) => repo.mostRecentPeriodStart());
      expect(reopened, isNotNull);
      expect(reopened!.id, id);
      expect(reopened.date, DateTime(2026, 8, 27));

      // Delete, then reopen again: gone for good.
      await withDb((repo) => repo.deleteEvent(id));
      final afterDelete = await withDb((repo) => repo.mostRecentPeriodStart());
      expect(afterDelete, isNull);
    },
  );
}
