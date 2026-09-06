/// Turn a raw `source_device` tag (schema v11, p8.2) into something to show the
/// user.
///
/// The tag olf stores is whatever the OS health store handed over verbatim:
///  * iOS — an `HKSource` / `HKDevice` name, already human-readable
///    ("Oura", "Garmin Connect", "Withings Health Mate").
///  * Android — a Health Connect `dataOrigin.packageName`
///    ("com.ouraring.oura", "com.garmin.android.apps.connectmobile").
///
/// This is a pure, table-driven prettifier — no widget logic, no I/O. An
/// unknown package name falls back to its last dotted segment (so a new
/// integration still reads tolerably); an unknown plain name passes through
/// untouched. Matching is case-insensitive on the package prefix.
library;

/// Known Health Connect package prefixes → display name. Prefixes, so a vendor
/// that ships more than one package id still resolves.
const Map<String, String> _knownPackagePrefixes = {
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

/// A user-facing label for [raw] (a stored `source_device` tag). Returns `null`
/// for a `null` / blank tag so callers can simply skip it.
String? prettyDeviceLabel(String? raw) {
  final tag = raw?.trim();
  if (tag == null || tag.isEmpty) return null;

  final lower = tag.toLowerCase();
  if (lower.contains('.')) {
    for (final entry in _knownPackagePrefixes.entries) {
      if (lower == entry.key || lower.startsWith('${entry.key}.')) {
        return entry.value;
      }
    }
    // Unknown package id: use the last segment, title-cased, as a best effort
    // ("com.acme.ringapp" → "Ringapp").
    final last = tag.split('.').where((s) => s.isNotEmpty).lastOrNull;
    if (last == null || last.isEmpty) return tag;
    return last[0].toUpperCase() + last.substring(1);
  }

  // A plain name (iOS HKSource / HKDevice) — already meant for humans.
  return tag;
}
