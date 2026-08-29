import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'secure_storage_pin_store.dart';

/// The platform secure store for the PIN credential. Overridden with a fake in
/// tests.
final pinStoreProvider = Provider<PinStore>((ref) => SecureStoragePinStore());

/// The stored PIN credential, or `null` when no PIN is set. Its presence **is**
/// the "PIN lock is on" signal. Re-read via `ref.invalidate` after set / clear.
final pinCredentialProvider = FutureProvider<PinCredential?>(
  (ref) => ref.watch(pinStoreProvider).read(),
);

/// Whether a PIN is currently set (resolves to `false` while still loading).
final pinIsSetProvider = Provider<bool>(
  (ref) => ref.watch(pinCredentialProvider).valueOrNull != null,
);

/// Whether the current app session has been unlocked. Starts `false`; set
/// `true` after a correct PIN (or after finishing first-run setup), and back to
/// `false` when the app is backgrounded (see `AppGate`).
final sessionUnlockedProvider = StateProvider<bool>((ref) => false);

/// Set / change / clear / verify the local PIN.
final pinControllerProvider = Provider<PinController>(
  (ref) => PinController(ref.watch(pinStoreProvider), ref),
);

/// Keeps the stored [PinCredential] and the derived providers in step.
class PinController {
  PinController(this._store, this._ref);

  final PinStore _store;
  final Ref _ref;

  /// Set or replace the PIN. Throws [PinException] if [pin] fails [validatePin].
  /// Hashing is CPU-bound (~150 ms) — callers should show progress.
  Future<void> setPin(String pin) async {
    final error = validatePin(pin);
    if (error != null) throw PinException(error);
    await _store.write(derivePinCredential(pin));
    _ref.invalidate(pinCredentialProvider);
  }

  /// Turn the PIN lock off.
  Future<void> clearPin() async {
    await _store.delete();
    _ref.invalidate(pinCredentialProvider);
    _ref.read(sessionUnlockedProvider.notifier).state = true;
  }

  /// `true` when [pin] matches the stored credential (or when no PIN is set).
  Future<bool> verify(String pin) async {
    final credential = await _store.read();
    if (credential == null) return true;
    return verifyPin(pin, credential);
  }
}
