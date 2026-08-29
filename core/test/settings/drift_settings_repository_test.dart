import 'package:drift/native.dart';
import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSettingsRepository(db, now: () => DateTime(2026, 8, 28));
  });
  tearDown(() => db.close());

  test('get returns null for an unset key', () async {
    expect(await repo.get('nope'), isNull);
  });

  test('set then get round-trips, and set replaces', () async {
    await repo.set(SettingKeys.temperatureUnit, 'fahrenheit');
    expect(await repo.get(SettingKeys.temperatureUnit), 'fahrenheit');

    await repo.set(SettingKeys.temperatureUnit, 'celsius');
    expect(await repo.get(SettingKeys.temperatureUnit), 'celsius');
  });

  test('remove clears a key; removing an unset key is a no-op', () async {
    await repo.set('k', 'v');
    await repo.remove('k');
    expect(await repo.get('k'), isNull);
    await repo.remove('k'); // no throw
  });

  test('watch emits the current value then every change', () async {
    final seen = <String?>[];
    final sub = repo.watch(SettingKeys.temperatureUnit).listen(seen.add);
    await pumpEventQueue();

    await repo.set(SettingKeys.temperatureUnit, 'fahrenheit');
    await pumpEventQueue();
    await repo.set(SettingKeys.temperatureUnit, 'celsius');
    await pumpEventQueue();
    await repo.remove(SettingKeys.temperatureUnit);
    await pumpEventQueue();

    await sub.cancel();
    expect(seen, [null, 'fahrenheit', 'celsius', null]);
  });
}
