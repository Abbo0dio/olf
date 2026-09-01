import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_core/olf_core.dart';

class _FakeLoggingActivityRepository implements LoggingActivityRepository {
  _FakeLoggingActivityRepository(this._stamps);

  final List<DateTime> _stamps;
  DateTime? lastSince;

  @override
  Future<List<DateTime>> recentLogTimestamps({
    required DateTime since,
    int limit = kPreferredHourQueryLimit,
  }) async {
    lastSince = since;
    return _stamps.where((t) => !t.isBefore(since)).toList();
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.now();

  List<DateTime> at(int hour, int count) {
    final base = DateTime(now.year, now.month, now.day - 2, hour);
    return [for (var i = 0; i < count; i++) base.add(Duration(minutes: i))];
  }

  ProviderContainer containerWith({
    required LoggingActivityRepository repo,
    bool databaseOpens = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) async =>
              databaseOpens ? db : throw const MissingDatabaseKeyException(),
        ),
        loggingActivityRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Let `appDatabaseProvider` settle (data or error) before reading the target,
  /// so `preferredHourProvider` sees a resolved gate.
  Future<int?> readPreferredHour(ProviderContainer c) async {
    try {
      await c.read(appDatabaseProvider.future);
    } catch (_) {
      // The DB-error branch is a state we deliberately exercise.
    }
    return c.read(preferredHourProvider.future);
  }

  test('enough recent logs clustered at an hour → that hour', () async {
    final container = containerWith(
      repo: _FakeLoggingActivityRepository(at(20, 10)),
    );
    expect(await readPreferredHour(container), 20);
  });

  test('too few recent logs → null', () async {
    final container = containerWith(
      repo: _FakeLoggingActivityRepository(at(20, 3)),
    );
    expect(await readPreferredHour(container), isNull);
  });

  test(
    'database not open (error branch) → null, repo never consulted',
    () async {
      final repo = _FakeLoggingActivityRepository(at(20, 10));
      final container = containerWith(repo: repo, databaseOpens: false);

      expect(await readPreferredHour(container), isNull);
      expect(repo.lastSince, isNull);
    },
  );

  test('asks the repository for roughly the last 30 days', () async {
    final repo = _FakeLoggingActivityRepository(at(9, 10));
    final container = containerWith(repo: repo);
    await readPreferredHour(container);

    final since = repo.lastSince!;
    final daysBack = now.difference(since).inDays;
    expect(daysBack, inInclusiveRange(29, 31));
  });
}
