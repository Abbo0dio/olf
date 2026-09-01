import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/quiet_hours_providers.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  group('encode/decode', () {
    test('round-trips a full window, both ends and the enabled flag', () {
      const window = QuietHours(
        startHour: 22,
        startMinute: 15,
        endHour: 6,
        endMinute: 45,
        enabled: true,
      );
      expect(decodeQuietHours(encodeQuietHours(window)), window);
    });

    test('round-trips a disabled window', () {
      expect(
        decodeQuietHours(encodeQuietHours(kDefaultQuietHours)),
        kDefaultQuietHours,
      );
    });

    test('absent / empty / malformed all decode to the disabled default', () {
      expect(decodeQuietHours(null), kDefaultQuietHours);
      expect(decodeQuietHours(''), kDefaultQuietHours);
      expect(decodeQuietHours('garbage'), kDefaultQuietHours);
      expect(decodeQuietHours('1;99'), kDefaultQuietHours);
      expect(decodeQuietHours('1;aa:bb;cc:dd'), kDefaultQuietHours);
    });
  });

  group('QuietHoursController', () {
    late AppDatabase db;
    late DriftSettingsRepository settings;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settings = DriftSettingsRepository(db);
    });
    tearDown(() => db.close());

    test(
      'save writes an encoding the store reads back as the same window',
      () async {
        const window = QuietHours(
          startHour: 21,
          startMinute: 30,
          endHour: 8,
          endMinute: 0,
          enabled: true,
        );

        await QuietHoursController(settings).save(window);

        expect(
          decodeQuietHours(await settings.get(SettingKeys.quietHours)),
          window,
        );
      },
    );
  });
}
