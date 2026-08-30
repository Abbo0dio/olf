import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'secure_storage_pin_store.dart';

/// The platform secure store for the real PIN credential. Overridden with a fake
/// in tests.
final pinStoreProvider = Provider<PinStore>((ref) => SecureStoragePinStore());

/// The platform secure store for the decoy / duress PIN credential (p2.2). A
/// separate storage entry from [pinStoreProvider]. Overridden with a fake in
/// tests.
final decoyPinStoreProvider = Provider<PinStore>(
  (ref) => SecureStoragePinStore(keyName: decoyPinCredentialKey),
);

/// The stored real PIN credential, or `null` when no PIN is set. Its presence
/// **is** the "PIN lock is on" signal. Re-read via `ref.invalidate` after
/// set / clear.
final pinCredentialProvider = FutureProvider<PinCredential?>(
  (ref) => ref.watch(pinStoreProvider).read(),
);

/// The stored decoy PIN credential, or `null` when none is set (p2.2).
final decoyPinCredentialProvider = FutureProvider<PinCredential?>(
  (ref) => ref.watch(decoyPinStoreProvider).read(),
);

/// Whether a real PIN is currently set (resolves to `false` while still
/// loading).
final pinIsSetProvider = Provider<bool>(
  (ref) => ref.watch(pinCredentialProvider).valueOrNull != null,
);

/// Whether a decoy PIN is currently set (p2.2).
final decoyPinIsSetProvider = Provider<bool>(
  (ref) => ref.watch(decoyPinCredentialProvider).valueOrNull != null,
);

/// Whether the current app session has been unlocked. Starts `false`; set
/// `true` after a correct PIN / decoy PIN (or after finishing first-run setup),
/// and back to `false` when the app is backgrounded (see `AppGate`).
final sessionUnlockedProvider = StateProvider<bool>((ref) => false);

/// Set / change / clear / route the local PIN and the decoy PIN.
final pinControllerProvider = Provider<PinController>(
  (ref) => PinController(
    ref.watch(pinStoreProvider),
    ref.watch(decoyPinStoreProvider),
    ref,
  ),
);

/// Keeps the stored PIN credentials and the derived providers in step.
class PinController {
  PinController(this._store, this._decoyStore, this._ref);

  final PinStore _store;
  final PinStore _decoyStore;
  final Ref _ref;

  /// Set or replace the real PIN. Throws [PinException] if [pin] fails
  /// [validatePin]. Hashing is CPU-bound (~150 ms) — callers should show
  /// progress.
  Future<void> setPin(String pin) async {
    final error = validatePin(pin);
    if (error != null) throw PinException(error);
    await _store.write(derivePinCredential(pin));
    _ref.invalidate(pinCredentialProvider);
  }

  /// Turn the real PIN lock off. Also clears any decoy PIN — a decoy without a
  /// real lock is meaningless.
  Future<void> clearPin() async {
    await _store.delete();
    await _decoyStore.delete();
    _ref.invalidate(pinCredentialProvider);
    _ref.invalidate(decoyPinCredentialProvider);
    _ref.read(sessionUnlockedProvider.notifier).state = true;
  }

  /// Set or replace the decoy PIN (p2.2). Throws [PinException] if [pin] fails
  /// [validatePin]. Callers must first reject a [pin] that equals the real PIN
  /// (see [matchesRealPin]).
  Future<void> setDecoyPin(String pin) async {
    final error = validatePin(pin);
    if (error != null) throw PinException(error);
    await _decoyStore.write(derivePinCredential(pin));
    _ref.invalidate(decoyPinCredentialProvider);
  }

  /// Turn the decoy PIN off (p2.2). The decoy database file is left in place.
  Future<void> clearDecoyPin() async {
    await _decoyStore.delete();
    _ref.invalidate(decoyPinCredentialProvider);
  }

  /// `true` when [pin] matches the real credential. Used to stop the decoy PIN
  /// from being set equal to the real one.
  Future<bool> matchesRealPin(String pin) async {
    final credential = await _store.read();
    return credential != null && verifyPin(pin, credential);
  }

  /// Which vault [pin] opens: the real one, the decoy one, or neither.
  Future<PinRoute> route(String pin) async {
    final real = await _store.read();
    final decoy = await _decoyStore.read();
    return routePin(pin, real: real, decoy: decoy);
  }

  /// `true` when [pin] matches the real credential (or when no real PIN is set).
  /// Retained for callers that only care about the real lock.
  Future<bool> verify(String pin) async {
    final credential = await _store.read();
    if (credential == null) return true;
    return verifyPin(pin, credential);
  }
}
