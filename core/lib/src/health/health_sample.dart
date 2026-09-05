import 'package:meta/meta.dart';

import '../date_math.dart';

/// The kinds of external health observation olf bridges to and from the OS
/// health platform (Apple HealthKit / Android Health Connect).
///
/// Deliberately a small, closed set — the five things the cycle engine actually
/// consumes. Adding a value is source-compatible; the platform impls (p6.2 iOS,
/// p6.3 Android) map each one to their native identifier.
enum HealthSampleType {
  menstrualFlow,
  basalBodyTemperature,
  bodyTemperature,
  wristTemperature,
  sleep,
}

/// The unit a [HealthSample.value] is expressed in.
///
/// A closed set on purpose — no free-text units — so every conversion lives in
/// one place (the platform mapping layer, p6.2/p6.3).
///
///  * [celsius] — a temperature reading, degrees Celsius (olf's canonical unit).
///  * [flowLevel] — menstrual-flow intensity as an ordinal `0..n`, lightest
///    first. The platform mapping owns the exact scale.
///  * [minutes] — a duration in whole minutes (a sleep stretch).
enum HealthUnit { celsius, flowLevel, minutes }

/// Where a sample originated.
///
///  * [manual] — a value the user typed into olf. Authoritative: never
///    overwritten by an import (see `ImportReconciler`).
///  * [appleHealth] / [healthConnect] — data that arrived over a
///    [HealthPlatformGateway].
enum HealthDataSource { manual, appleHealth, healthConnect }

/// Read / write intent for [HealthPlatformGateway.requestAuthorization] and
/// [HealthPlatformGateway.authorizationStatus].
enum HealthAccess { read, write, readWrite }

/// A single external health observation, platform-agnostic.
///
/// A pure value type — **no Flutter, no `DateTime.now()`**. A *point* sample (a
/// BBT reading, a flow entry) has `endAt == startAt`; an *interval* sample (a
/// sleep stretch) has `endAt` after `startAt`. Temperatures are always Celsius;
/// the °C / °F display choice is a separate app preference.
@immutable
class HealthSample {
  HealthSample({
    required this.type,
    required this.startAt,
    required this.endAt,
    required this.value,
    required this.unit,
    required this.source,
    this.externalId,
  }) : assert(
         !endAt.isBefore(startAt),
         'HealthSample.endAt must not be before startAt',
       ),
       assert(
         _unitMatchesType(type, unit),
         'HealthSample unit does not match its type',
       );

  /// A point-in-time sample — `endAt` is pinned to `at`.
  HealthSample.point({
    required HealthSampleType type,
    required DateTime at,
    required double value,
    required HealthUnit unit,
    required HealthDataSource source,
    String? externalId,
  }) : this(
         type: type,
         startAt: at,
         endAt: at,
         value: value,
         unit: unit,
         source: source,
         externalId: externalId,
       );

  final HealthSampleType type;

  /// Start of the observation (local time). For a point sample this is "when".
  final DateTime startAt;

  /// End of the observation. Equal to [startAt] for a point sample.
  final DateTime endAt;

  /// The reading, in [unit].
  final double value;
  final HealthUnit unit;
  final HealthDataSource source;

  /// The platform's stable identifier for this sample, when it came from one —
  /// lets a later sync match instead of duplicating. `null` for a sample olf
  /// is about to write out, or a [HealthDataSource.manual] value.
  final String? externalId;

  /// `true` when this is a point-in-time reading (`endAt == startAt`).
  bool get isPointSample => endAt.isAtSameMomentAs(startAt);

  /// The calendar day the sample is anchored to (its [startAt], time stripped).
  DateTime get day => dateOnly(startAt);

  HealthSample copyWith({
    HealthSampleType? type,
    DateTime? startAt,
    DateTime? endAt,
    double? value,
    HealthUnit? unit,
    HealthDataSource? source,
    String? externalId,
    bool clearExternalId = false,
  }) => HealthSample(
    type: type ?? this.type,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    source: source ?? this.source,
    externalId: clearExternalId ? null : (externalId ?? this.externalId),
  );

  @override
  bool operator ==(Object other) =>
      other is HealthSample &&
      other.type == type &&
      other.startAt == startAt &&
      other.endAt == endAt &&
      other.value == value &&
      other.unit == unit &&
      other.source == source &&
      other.externalId == externalId;

  @override
  int get hashCode =>
      Object.hash(type, startAt, endAt, value, unit, source, externalId);

  @override
  String toString() =>
      'HealthSample($type, $startAt..$endAt, $value $unit, $source, '
      'externalId: $externalId)';
}

/// Whether [unit] is a legal unit for [type]. Enforced by the [HealthSample]
/// constructor so a mis-mapped platform value fails loudly at the seam.
bool _unitMatchesType(HealthSampleType type, HealthUnit unit) => switch (type) {
  HealthSampleType.menstrualFlow => unit == HealthUnit.flowLevel,
  HealthSampleType.basalBodyTemperature ||
  HealthSampleType.bodyTemperature ||
  HealthSampleType.wristTemperature => unit == HealthUnit.celsius,
  HealthSampleType.sleep => unit == HealthUnit.minutes,
};
