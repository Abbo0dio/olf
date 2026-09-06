import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('is ordered none < mild < moderate < severe', () {
    expect(SymptomSeverity.values, [
      SymptomSeverity.none,
      SymptomSeverity.mild,
      SymptomSeverity.moderate,
      SymptomSeverity.severe,
    ]);
    expect(SymptomSeverity.ordered, SymptomSeverity.values);
  });

  test('rank is 0..3 ascending with severity', () {
    expect(SymptomSeverity.none.rank, 0);
    expect(SymptomSeverity.mild.rank, 1);
    expect(SymptomSeverity.moderate.rank, 2);
    expect(SymptomSeverity.severe.rank, 3);

    final ranks = SymptomSeverity.values.map((s) => s.rank).toList();
    final sorted = [...ranks]..sort();
    expect(ranks, sorted);
  });

  test('label is a short sentence-case word', () {
    expect(SymptomSeverity.none.label, 'None');
    expect(SymptomSeverity.mild.label, 'Mild');
    expect(SymptomSeverity.moderate.label, 'Moderate');
    expect(SymptomSeverity.severe.label, 'Severe');
  });

  test('name round-trips (the form drift persists)', () {
    for (final s in SymptomSeverity.values) {
      expect(SymptomSeverity.values.byName(s.name), s);
    }
  });
}
