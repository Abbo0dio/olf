import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('validateMedicationName', () {
    test('accepts a normal name', () {
      expect(validateMedicationName('Sertraline'), isNull);
    });

    test('trims before checking', () {
      expect(validateMedicationName('   '), MedicationError.nameEmpty);
      expect(validateMedicationName('  Iron  '), isNull);
    });

    test('rejects an over-long name', () {
      expect(
        validateMedicationName('x' * (maxMedicationNameLength + 1)),
        MedicationError.nameTooLong,
      );
      expect(validateMedicationName('x' * maxMedicationNameLength), isNull);
    });
  });

  test('MedicationError.describe is a non-empty sentence', () {
    for (final e in MedicationError.values) {
      expect(e.describe(), isNotEmpty);
    }
  });

  test('MedicationException carries the error and describes it', () {
    const ex = MedicationException(MedicationError.nameEmpty);
    expect(ex.error, MedicationError.nameEmpty);
    expect(ex.toString(), contains('name'));
  });
}
