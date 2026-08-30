import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/main.dart';
import 'package:olf_app/src/onboarding/onboarding_providers.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_app/src/security/biometric_gateway.dart';
import 'package:olf_app/src/security/biometric_providers.dart';
import 'package:olf_app/src/security/pin_providers.dart';
import 'package:olf_core/olf_core.dart';

/// A fresh in-memory database, closed automatically at the end of the test.
AppDatabase memoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Override [appDatabaseProvider] to hand out [db] already opened.
Override dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWith((ref) async => db);

/// An in-memory [PinStore] for tests. Seed it with a credential (via
/// [derivePinCredential]) to exercise the lock screen.
class FakePinStore implements PinStore {
  FakePinStore([this._credential]);

  PinCredential? _credential;

  @override
  Future<PinCredential?> read() async => _credential;

  @override
  Future<void> write(PinCredential credential) async =>
      _credential = credential;

  @override
  Future<void> delete() async => _credential = null;
}

/// An in-memory [BiometricGateway] for tests. Defaults to "no biometric on this
/// device" so the lock screen behaves exactly as it did pre-p2.1; set [capable]
/// true (and turn the setting on) to exercise the shortcut.
class FakeBiometricGateway implements BiometricGateway {
  FakeBiometricGateway({
    this.capable = false,
    this.result = BiometricAuthResult.success,
  });

  bool capable;
  BiometricAuthResult result;
  int prompts = 0;

  @override
  Future<bool> canAuthenticate() async => capable;

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    prompts++;
    return result;
  }
}

/// Resolve Future/Stream microtasks and short animations. **Not**
/// `pumpAndSettle` — the loading state animates a spinner forever.
Future<void> flush(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Pump [OlfApp] with [overrides], run [body], then tear the tree down **inside
/// the test body** and pump once more — that last step flushes drift's
/// stream-close timer before the binding's pending-timer check runs.
/// A surface tall enough that the whole calendar screen fits without scrolling,
/// so taps land without `ensureVisible` gymnastics.
Future<void> useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pump the app behind its p1.8 gate.
///
/// By default the gate is transparent: [onboarded] short-circuits the first-run
/// explainer, and [pinStore] defaults to an empty in-memory store (no PIN, so
/// no lock screen). Pass `onboarded: false` to land on the first-run screen, or
/// a seeded [FakePinStore] to land on the lock screen. [biometricGateway]
/// defaults to an incapable [FakeBiometricGateway] (no biometric hardware).
Future<void> pumpOlf(
  WidgetTester tester, {
  required List<Override> overrides,
  required Future<void> Function() body,
  bool onboarded = true,
  PinStore? pinStore,
  BiometricGateway? biometricGateway,
}) async {
  await useTallSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        pinStoreProvider.overrideWithValue(pinStore ?? FakePinStore()),
        biometricGatewayProvider.overrideWithValue(
          biometricGateway ?? FakeBiometricGateway(),
        ),
        if (onboarded) firstRunDoneProvider.overrideWith((ref) async => true),
      ],
      child: const OlfApp(),
    ),
  );
  await flush(tester);
  await body();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
