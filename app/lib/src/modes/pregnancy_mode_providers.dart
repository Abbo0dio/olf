import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// `app_settings` key holding the pregnancy-mode start reference (p7.2a).
///
/// The app layer owns the encoding (like `quiet_hours` / `app_icon`): a
/// `"<kind>|<yyyy-mm-dd>"` string — e.g. `"lastMenstrualPeriod|2026-01-05"`.
/// Absent means the mode has been turned on but no start date entered yet.
/// **No schema change** — it is one row in the existing KV store.
const String pregnancyStartReferenceKey = 'pregnancy.start_reference';

/// Encode a [PregnancyStartReference] for [pregnancyStartReferenceKey].
String encodePregnancyStartReference(PregnancyStartReference reference) {
  final d = reference.date;
  final iso =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return '${reference.kind.name}|$iso';
}

/// Decode a stored value, or `null` if it is absent or unparseable.
PregnancyStartReference? decodePregnancyStartReference(String? stored) {
  if (stored == null) return null;
  final sep = stored.indexOf('|');
  if (sep <= 0) return null;
  final kindName = stored.substring(0, sep);
  PregnancyReferenceKind? kind;
  for (final k in PregnancyReferenceKind.values) {
    if (k.name == kindName) kind = k;
  }
  final date = DateTime.tryParse(stored.substring(sep + 1));
  if (kind == null || date == null) return null;
  return PregnancyStartReference(kind: kind, date: date);
}

/// The stored pregnancy start reference, live. `null` until one is set (or the
/// database is still opening).
final pregnancyStartReferenceProvider =
    StreamProvider<PregnancyStartReference?>((ref) {
      final db = ref.watch(appDatabaseProvider);
      if (db is! AsyncData) {
        return Stream<PregnancyStartReference?>.value(null);
      }
      return ref
          .watch(settingsRepositoryProvider)
          .watch(pregnancyStartReferenceKey)
          .map(decodePregnancyStartReference);
    });

/// Store the pregnancy start reference (LMP / due date / conception date).
Future<void> setPregnancyStartReference(
  WidgetRef ref,
  PregnancyStartReference reference,
) => ref
    .read(settingsRepositoryProvider)
    .set(pregnancyStartReferenceKey, encodePregnancyStartReference(reference));

/// Clear the stored start reference. Turning pregnancy mode off does **not**
/// call this — the reference is kept so re-enabling resumes where it was.
Future<void> clearPregnancyStartReference(WidgetRef ref) =>
    ref.read(settingsRepositoryProvider).remove(pregnancyStartReferenceKey);

/// Gestational age as of today, or `null` when no start reference is set or the
/// reference is in the future. `DateTime.now()` is read at this edge, matching
/// `postpartumCycleReturnProvider`; `core` stays clock-injected.
final gestationalAgeProvider = Provider<GestationalAge?>((ref) {
  final reference = ref.watch(pregnancyStartReferenceProvider).value;
  if (reference == null) return null;
  return gestationalAgeAsOf(reference, asOf: DateTime.now());
});
