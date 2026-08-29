import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  group('validateSymptomName', () {
    test('accepts a plain new name', () {
      expect(
        validateSymptomName('Dizziness', existingActiveNames: const ['Cramps']),
        isNull,
      );
    });

    test('trims surrounding whitespace before checking', () {
      expect(
        validateSymptomName('   ', existingActiveNames: const []),
        SymptomTypeError.empty,
      );
      expect(
        validateSymptomName('  Cravings  ', existingActiveNames: const []),
        isNull,
      );
    });

    test('rejects a name longer than the column limit', () {
      final long = 'a' * (maxSymptomNameLength + 1);
      expect(
        validateSymptomName(long, existingActiveNames: const []),
        SymptomTypeError.tooLong,
      );
      final atLimit = 'a' * maxSymptomNameLength;
      expect(
        validateSymptomName(atLimit, existingActiveNames: const []),
        isNull,
      );
    });

    test('rejects a case-insensitive duplicate of an active name', () {
      expect(
        validateSymptomName('cramps', existingActiveNames: const ['Cramps']),
        SymptomTypeError.duplicate,
      );
    });

    test('lets a rename keep its own name (e.g. a pure case change)', () {
      expect(
        validateSymptomName(
          'Cramps',
          existingActiveNames: const ['cramps', 'Bloating'],
          editingCurrentName: 'cramps',
        ),
        isNull,
      );
    });

    test(
      'still blocks a rename that collides with a different active name',
      () {
        expect(
          validateSymptomName(
            'Bloating',
            existingActiveNames: const ['Cramps', 'Bloating'],
            editingCurrentName: 'Cramps',
          ),
          SymptomTypeError.duplicate,
        );
      },
    );

    test('describe() gives a non-empty sentence for every error', () {
      for (final e in SymptomTypeError.values) {
        expect(e.describe(), isNotEmpty);
      }
    });
  });
}
