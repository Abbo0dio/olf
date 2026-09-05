import 'health_sample.dart';

/// Thrown by every data-bearing [HealthPlatformGateway] call when the platform
/// is not usable on this device / OS build.
///
/// Callers gate on [HealthPlatformGateway.isAvailable] first; this exception is
/// the backstop for a race (the platform going away between the check and the
/// call) and for tests.
class HealthPlatformUnavailable implements Exception {
  const HealthPlatformUnavailable([
    this.message = 'the OS health platform is not available on this device',
  ]);

  final String message;

  @override
  String toString() => 'HealthPlatformUnavailable: $message';
}

/// The authorization state for a set of [HealthSampleType]s and an access mode.
///
///  * [granted] — every requested type is authorized for the requested access.
///  * [denied] — the user has refused at least one.
///  * [notDetermined] — not asked yet (or the platform won't say, which iOS
///    does for read scopes by design).
enum HealthAuthStatus { granted, denied, notDetermined }

/// A platform-agnostic bridge to the OS health store.
///
/// This is the "swap the plugin" seam (DEVELOPMENT_PLAN.md §2): `core` owns the
/// interface, the sample model and the reconciliation engine; the concrete
/// implementations live in `app/` — one per platform (p6.2 Apple HealthKit,
/// p6.3 Android Health Connect) — and the desktop shell (Phase 13) simply binds
/// an unavailable gateway.
///
/// **Availability contract.** When [isAvailable] is `false`, every method except
/// [isAvailable] itself throws [HealthPlatformUnavailable]. Implementations must
/// not silently no-op.
///
/// Nothing here touches the network: HealthKit / Health Connect are local IPC.
abstract class HealthPlatformGateway {
  /// `true` when the OS health platform can be reached on this device.
  ///
  /// `false` on the iOS simulator without Health, on Android without Health
  /// Connect installed, on desktop, and in most tests.
  bool get isAvailable;

  /// Ask the user to authorize [types] for [access].
  ///
  /// Idempotent from the app's side — calling it again when already granted is
  /// harmless. Throws [HealthPlatformUnavailable] when [isAvailable] is `false`.
  Future<HealthAuthStatus> requestAuthorization(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  });

  /// The current authorization state for [types] / [access] without prompting.
  ///
  /// Throws [HealthPlatformUnavailable] when [isAvailable] is `false`.
  Future<HealthAuthStatus> authorizationStatus(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  });

  /// Read every authorized sample of [types] whose [HealthSample.startAt] is in
  /// the inclusive range [from]..[to].
  ///
  /// Types the user has not granted read access to are simply absent from the
  /// result — not an error. Throws [HealthPlatformUnavailable] when
  /// [isAvailable] is `false`.
  Future<List<HealthSample>> read({
    required Set<HealthSampleType> types,
    required DateTime from,
    required DateTime to,
  });

  /// Write [samples] to the platform.
  ///
  /// A sample carrying an [HealthSample.externalId] the platform already knows
  /// is an update; otherwise it is an insert (and the platform assigns the id).
  /// Writing a type the platform treats as read-only (Apple sleeping wrist
  /// temperature) is a silent no-op for that sample, not a throw. Throws
  /// [HealthPlatformUnavailable] when [isAvailable] is `false`.
  Future<void> write(List<HealthSample> samples);

  /// Delete every sample of [type] whose start is in [from]..[to] that olf is
  /// allowed to delete (typically only samples olf itself wrote).
  ///
  /// Throws [HealthPlatformUnavailable] when [isAvailable] is `false`.
  Future<void> delete({
    required HealthSampleType type,
    required DateTime from,
    required DateTime to,
  });
}

/// An in-memory [HealthPlatformGateway] for tests and for the platforms that
/// have no health store.
///
/// Scriptable: [available] flips the availability contract, [authOutcome] (and
/// the per-type [seedStatus]) drive [requestAuthorization] / [authorizationStatus],
/// and [seedSamples] pre-loads the store. It records [authRequests] and
/// [writes] so a test can assert on what the code under test asked for.
class FakeHealthPlatformGateway implements HealthPlatformGateway {
  FakeHealthPlatformGateway({
    this.available = true,
    HealthAuthStatus authOutcome = HealthAuthStatus.granted,
    Map<HealthSampleType, HealthAuthStatus>? seedStatus,
    Iterable<HealthSample> seedSamples = const [],
  }) : _authOutcome = authOutcome,
       _statusByType = {...?seedStatus},
       _store = [...seedSamples];

  /// Drives [isAvailable]; mutable so a test can simulate the platform
  /// appearing / disappearing.
  bool available;

  HealthAuthStatus _authOutcome;
  final Map<HealthSampleType, HealthAuthStatus> _statusByType;
  final List<HealthSample> _store;

  /// Every [requestAuthorization] call, in order.
  final List<({Set<HealthSampleType> types, HealthAccess access})>
  authRequests = [];

  /// Every sample passed to [write], flattened across calls.
  final List<HealthSample> writes = [];

  /// The current contents of the fake store.
  List<HealthSample> get samples => List.unmodifiable(_store);

  /// Set the outcome the next [requestAuthorization] will apply to its types.
  void scriptAuthOutcome(HealthAuthStatus outcome) => _authOutcome = outcome;

  /// Add one sample to the store directly (no auth check).
  void seed(HealthSample sample) => _store.add(sample);

  void _ensureAvailable() {
    if (!available) throw const HealthPlatformUnavailable();
  }

  @override
  bool get isAvailable => available;

  @override
  Future<HealthAuthStatus> requestAuthorization(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async {
    _ensureAvailable();
    authRequests.add((types: {...types}, access: access));
    for (final t in types) {
      _statusByType[t] = _authOutcome;
    }
    return _authOutcome;
  }

  @override
  Future<HealthAuthStatus> authorizationStatus(
    Set<HealthSampleType> types, {
    required HealthAccess access,
  }) async {
    _ensureAvailable();
    if (types.isEmpty) return HealthAuthStatus.notDetermined;
    final seen = {
      for (final t in types) _statusByType[t] ?? HealthAuthStatus.notDetermined,
    };
    if (seen.length == 1) return seen.single;
    // Mixed — report the most cautious answer.
    if (seen.contains(HealthAuthStatus.denied)) return HealthAuthStatus.denied;
    return HealthAuthStatus.notDetermined;
  }

  @override
  Future<List<HealthSample>> read({
    required Set<HealthSampleType> types,
    required DateTime from,
    required DateTime to,
  }) async {
    _ensureAvailable();
    return _store
        .where((s) => types.contains(s.type))
        .where((s) => !s.startAt.isBefore(from) && !s.startAt.isAfter(to))
        .toList(growable: false);
  }

  @override
  Future<void> write(List<HealthSample> samples) async {
    _ensureAvailable();
    for (final s in samples) {
      writes.add(s);
      final ext = s.externalId;
      final at = ext == null
          ? -1
          : _store.indexWhere((e) => e.externalId == ext);
      if (at >= 0) {
        _store[at] = s;
      } else {
        _store.add(s);
      }
    }
  }

  @override
  Future<void> delete({
    required HealthSampleType type,
    required DateTime from,
    required DateTime to,
  }) async {
    _ensureAvailable();
    _store.removeWhere(
      (s) =>
          s.type == type && !s.startAt.isBefore(from) && !s.startAt.isAfter(to),
    );
  }
}
