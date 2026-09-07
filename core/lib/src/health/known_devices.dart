/// The registry of third-party health sources olf recognises by name — shared
/// by the display prettifier (`app/lib/src/health/device_label.dart`) and the
/// p8.6 multi-source precedence classifier (`source_precedence.dart`) so the two
/// can never drift.
///
/// Pure data + two pure lookups. No Flutter, no I/O.
///
/// What olf stores in `source_device` (schema v11, p8.2) is whatever the OS
/// health store handed over verbatim:
///  * iOS — an `HKSource` / `HKDevice` name, already human-readable
///    ("Oura", "Garmin Connect", "Withings Health Mate").
///  * Android — a Health Connect `dataOrigin.packageName`
///    ("com.ouraring.oura", "com.garmin.android.apps.connectmobile").
library;

/// Known Health Connect package **prefixes** → canonical vendor label. Prefixes,
/// so a vendor that ships more than one package id still resolves. Keys are
/// lower-case; matching is case-insensitive.
const Map<String, String> knownDevicePackagePrefixes = {
  'com.ouraring': 'Oura',
  'com.garmin': 'Garmin',
  'com.google.android.apps.fitness': 'Google Fit',
  'com.google.android.apps.healthdata': 'Health Connect',
  'com.withings': 'Withings',
  'com.fitbit': 'Fitbit',
  'com.samsung.android.app.health': 'Samsung Health',
  'com.samsung.health': 'Samsung Health',
  'com.whoop': 'WHOOP',
  'com.polar': 'Polar',
  'com.wahoofitness': 'Wahoo',
};

/// Known iOS `HKSource` / `HKDevice` plain names (lower-cased) → canonical
/// vendor label. iOS names are already meant for humans, so this is a short
/// allow-list of the ones whose exact spelling we want to normalise / recognise
/// as an attributed device.
const Map<String, String> knownDevicePlainNames = {
  'oura': 'Oura',
  'garmin': 'Garmin',
  'garmin connect': 'Garmin',
  'withings': 'Withings',
  'withings health mate': 'Withings',
  'fitbit': 'Fitbit',
  'whoop': 'WHOOP',
  'polar': 'Polar',
  'polar flow': 'Polar',
  'samsung health': 'Samsung Health',
  'wahoo': 'Wahoo',
};

/// The canonical vendor label for a stored `source_device` [raw] tag, or `null`
/// when the tag is blank or names no source olf recognises.
///
/// A package id matches on prefix (`com.ouraring.oura` → `Oura`); a plain name
/// matches the [knownDevicePlainNames] allow-list exactly (case-insensitive,
/// trimmed).
String? knownVendorLabel(String? raw) {
  final tag = raw?.trim();
  if (tag == null || tag.isEmpty) return null;
  final lower = tag.toLowerCase();

  if (lower.contains('.')) {
    for (final entry in knownDevicePackagePrefixes.entries) {
      if (lower == entry.key || lower.startsWith('${entry.key}.')) {
        return entry.value;
      }
    }
    return null;
  }
  return knownDevicePlainNames[lower];
}

/// Whether [raw] names a health source olf recognises as a specific device / app
/// (an Oura ring, a Garmin watch, …) rather than a bare, unattributed platform
/// sample. Drives the p8.6 precedence classifier's dedicated-device rank.
bool isAttributedDevice(String? raw) => knownVendorLabel(raw) != null;
