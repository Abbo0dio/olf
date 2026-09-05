import 'package:olf_core/olf_core.dart';

/// Apple HealthKit `HKCategoryValueMenstrualFlow` raw values.
///
/// HealthKit models a menstrual-flow entry as a category sample whose value is
/// one of these. olf's own scale is [FlowIntensity] (`spotting` → `heavy`); this
/// file is the whole of the translation and is deliberately pure so it can be
/// unit-tested without a channel.
const int hkMenstrualFlowUnspecified = 1;
const int hkMenstrualFlowLight = 2;
const int hkMenstrualFlowMedium = 3;
const int hkMenstrualFlowHeavy = 4;
const int hkMenstrualFlowNone = 5;

/// Map an incoming HealthKit menstrual-flow value to an [FlowIntensity].
///
/// Returns `null` for [hkMenstrualFlowNone] (HealthKit's "logged, but no flow"
/// marker — olf represents that as the absence of a row, so there is nothing to
/// import) and for any value outside the known set.
///
/// `unspecified` has no exact olf equivalent; it maps to the lightest level,
/// [FlowIntensity.spotting], which is also what olf sends back out for spotting
/// so the pairing round-trips.
FlowIntensity? flowIntensityFromHk(int hkValue) {
  switch (hkValue) {
    case hkMenstrualFlowUnspecified:
      return FlowIntensity.spotting;
    case hkMenstrualFlowLight:
      return FlowIntensity.light;
    case hkMenstrualFlowMedium:
      return FlowIntensity.medium;
    case hkMenstrualFlowHeavy:
      return FlowIntensity.heavy;
    case hkMenstrualFlowNone:
      return null;
    default:
      return null;
  }
}

/// Map an olf [FlowIntensity] to the HealthKit menstrual-flow value olf writes
/// out. [FlowIntensity.spotting] — which HealthKit has no name for — goes to
/// `unspecified`; the other three are exact.
int hkValueFromFlowIntensity(FlowIntensity intensity) {
  switch (intensity) {
    case FlowIntensity.spotting:
      return hkMenstrualFlowUnspecified;
    case FlowIntensity.light:
      return hkMenstrualFlowLight;
    case FlowIntensity.medium:
      return hkMenstrualFlowMedium;
    case FlowIntensity.heavy:
      return hkMenstrualFlowHeavy;
  }
}
