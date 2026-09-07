import 'package:olf_core/olf_core.dart';

/// Turn a raw `source_device` tag (schema v11, p8.2) into something to show the
/// user.
///
/// The tag olf stores is whatever the OS health store handed over verbatim:
///  * iOS — an `HKSource` / `HKDevice` name, already human-readable
///    ("Oura", "Garmin Connect", "Withings Health Mate").
///  * Android — a Health Connect `dataOrigin.packageName`
///    ("com.ouraring.oura", "com.garmin.android.apps.connectmobile").
///
/// This is a pure, table-driven prettifier — no widget logic, no I/O. The known
/// package-prefix table lives in `core` ([knownDevicePackagePrefixes]) and is
/// shared with the p8.6 multi-source precedence classifier so the two never
/// drift. An unknown package name falls back to its last dotted segment (so a
/// new integration still reads tolerably); an unknown plain name passes through
/// untouched. Matching is case-insensitive on the package prefix.

/// A user-facing label for [raw] (a stored `source_device` tag). Returns `null`
/// for a `null` / blank tag so callers can simply skip it.
String? prettyDeviceLabel(String? raw) {
  final tag = raw?.trim();
  if (tag == null || tag.isEmpty) return null;

  final lower = tag.toLowerCase();
  if (lower.contains('.')) {
    for (final entry in knownDevicePackagePrefixes.entries) {
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
