import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/monetization/subscription_prompt_providers.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Let `appDatabaseProvider` settle so the provider sees a resolved DB gate.
  Future<bool> readAllowed(ProviderContainer c) async {
    await c.read(appDatabaseProvider.future);
    return c.read(subscriptionPromptsAllowedProvider.future);
  }

  test('default: nothing stored → prompts allowed', () async {
    expect(await readAllowed(container()), isTrue);
  });

  test('suppressed setting → provider reports not allowed', () async {
    await DriftSettingsRepository(
      db,
    ).set(SettingKeys.suppressSubscriptionPrompts, 'true');

    expect(await readAllowed(container()), isFalse);
  });

  test(
    'the choice survives a reload — a fresh container re-reads it',
    () async {
      await DriftSettingsRepository(
        db,
      ).set(SettingKeys.suppressSubscriptionPrompts, 'true');
      expect(await readAllowed(container()), isFalse);

      // A brand-new container over the same database, as on next launch.
      expect(await readAllowed(container()), isFalse);
    },
  );

  test('turning it back off re-allows prompts', () async {
    final settings = DriftSettingsRepository(db);
    await settings.set(SettingKeys.suppressSubscriptionPrompts, 'true');
    expect(await readAllowed(container()), isFalse);

    await settings.set(SettingKeys.suppressSubscriptionPrompts, 'false');
    expect(await readAllowed(container()), isTrue);
  });

  test(
    'database not open → allowed (fails open, never hides silently)',
    () async {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith(
            (ref) async => throw const MissingDatabaseKeyException(),
          ),
        ],
      );
      addTearDown(c.dispose);

      try {
        await c.read(appDatabaseProvider.future);
      } catch (_) {
        // The DB-error branch is deliberately exercised.
      }
      expect(await c.read(subscriptionPromptsAllowedProvider.future), isTrue);
    },
  );
}
