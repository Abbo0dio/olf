/// An ordered, four-point severity scale — olf's first ranked symptom scale
/// (p7.5, endometriosis pain intensity).
///
/// Kept deliberately generic (not `PainSeverity`): p7.6 (PMDD) reuses this
/// **verbatim** for its daily multi-symptom rating rather than inventing a
/// second scale. Anything scale-specific (the pain-region set, PMDD's item
/// list) lives with that mode, not here.
///
/// [none] is included so a caller that rates something every day (PMDD) can
/// record "nothing today" as a real value. p7.5 never stores a `none` row —
/// clearing the day deletes the row instead — but the enum still carries it so
/// the ordering and [rank] line up with a 0-based scale.
enum SymptomSeverity {
  none,
  mild,
  moderate,
  severe;

  /// 0..3, ascending with severity. Stable — persisted indirectly (the enum
  /// *name* is what drift stores) and safe to use for comparisons and chart
  /// heights.
  int get rank => index;

  /// Short, sentence-case label for UI and screen readers.
  String get label => switch (this) {
    SymptomSeverity.none => 'None',
    SymptomSeverity.mild => 'Mild',
    SymptomSeverity.moderate => 'Moderate',
    SymptomSeverity.severe => 'Severe',
  };

  /// The scale as a list, lightest first — for building an ordered picker.
  static const List<SymptomSeverity> ordered = values;
}
