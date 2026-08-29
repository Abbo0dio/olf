import 'package:olf_core/olf_core.dart';

/// `2 symptoms` / `1 symptom` — used in day-cell screen-reader labels and the
/// summary chip.
String symptomCountLabel(int count) => '$count symptom${count == 1 ? '' : 's'}';

/// A day's symptoms as one comma-separated phrase, in catalogue order.
String symptomSummary(Iterable<String> names) => names.join(', ');

/// Resolve [ids] to catalogue names, preserving [types]' order and silently
/// dropping any id whose symptom has since been removed (archived).
List<String> symptomNames(Iterable<int> ids, List<SymptomType> types) {
  final wanted = ids.toSet();
  return [
    for (final t in types)
      if (wanted.contains(t.id)) t.name,
  ];
}
