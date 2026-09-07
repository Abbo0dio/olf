import 'health_sample.dart';
import 'known_devices.dart';

/// The precedence tier of one health reading in p8.6 multi-source arbitration.
/// A higher [rank] wins.
///
/// The v1 order is **fixed and documented** (`docs/health-platform-interop.md`);
/// per-user reordering is a backlog follow-up. Only [manual] ever wins outright
/// without the user's say-so — an automatic reading that outranks another is
/// auto-resolved, but a disagreement with a [manual] value always routes to the
/// user.
enum SourcePrecedenceTier {
  /// A bare automatic platform sample with no device attribution olf
  /// recognises — the lowest-trust automatic reading.
  genericPlatform(0),

  /// An Apple Watch overnight sleeping-wrist temperature (p8.1a). More
  /// trustworthy than an unattributed sample, less than a dedicated device.
  sleepingWrist(1),

  /// An automatic reading tagged with a device / app olf recognises
  /// (Oura, Garmin, Withings, …) — treated as a dedicated measurement device.
  attributedDevice(2),

  /// A value the user typed into olf. Always wins; never auto-resolved.
  manual(3);

  const SourcePrecedenceTier(this.rank);

  /// Sort key — higher wins. Compare with [outranks] / [compareTiers] rather
  /// than reading this directly at call sites.
  final int rank;

  /// `true` when this tier beats [other] outright.
  bool outranks(SourcePrecedenceTier other) => rank > other.rank;
}

/// `> 0` when [a] outranks [b], `< 0` when [b] outranks [a], `0` when they share
/// a tier (a genuine tie the reconciler hands to the user).
int compareTiers(SourcePrecedenceTier a, SourcePrecedenceTier b) =>
    a.rank.compareTo(b.rank);

/// Classify one reading into its [SourcePrecedenceTier] from exactly what olf
/// stores about it: the [source] enum, whether the row is an Apple-Watch
/// sleeping-wrist reading ([isSleepingWrist], from the p8.1a `measurement_kind`
/// column), and the free-form `source_device` tag ([sourceDevice], schema v11 /
/// p8.2).
///
/// The mapping, in order:
///  1. `source == manual` → [SourcePrecedenceTier.manual].
///  2. `isSleepingWrist` → [SourcePrecedenceTier.sleepingWrist] (regardless of
///     the device string — the Apple Watch is the wrist rank).
///  3. `sourceDevice` names a source olf recognises ([isAttributedDevice]) →
///     [SourcePrecedenceTier.attributedDevice].
///  4. otherwise → [SourcePrecedenceTier.genericPlatform].
///
/// Pure and total. Documented in `docs/health-platform-interop.md`.
SourcePrecedenceTier sourcePrecedenceTier({
  required HealthDataSource source,
  required bool isSleepingWrist,
  required String? sourceDevice,
}) {
  if (source == HealthDataSource.manual) return SourcePrecedenceTier.manual;
  if (isSleepingWrist) return SourcePrecedenceTier.sleepingWrist;
  if (isAttributedDevice(sourceDevice)) {
    return SourcePrecedenceTier.attributedDevice;
  }
  return SourcePrecedenceTier.genericPlatform;
}
