import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

void main() {
  test('unspecified resolves to they/them', () {
    final f = formsFor(Pronouns.unspecified);
    expect(f.subject, 'they');
    expect(f.object, 'them');
    expect(f.possessiveDeterminer, 'their');
    expect(f.pluralVerbs, isTrue);
    expect(
      identical(formsFor(Pronouns.unspecified), formsFor(Pronouns.theyThem)),
      isTrue,
    );
  });

  test('she/her and he/him forms', () {
    final she = formsFor(Pronouns.sheHer);
    expect(
      [she.subject, she.object, she.possessiveDeterminer, she.reflexive],
      ['she', 'her', 'her', 'herself'],
    );
    expect(she.pluralVerbs, isFalse);
    expect(she.verb('log'), 'logs');

    final he = formsFor(Pronouns.heHim);
    expect(
      [he.subject, he.object, he.possessiveDeterminer, he.possessivePronoun],
      ['he', 'him', 'his', 'his'],
    );
  });

  test('subjectCapitalized and verb agreement', () {
    expect(formsFor(Pronouns.theyThem).subjectCapitalized, 'They');
    expect(formsFor(Pronouns.sheHer).subjectCapitalized, 'She');
    expect(formsFor(Pronouns.theyThem).verb('log'), 'log');
    expect(formsFor(Pronouns.heHim).verb('update'), 'updates');
  });

  test('describePronouns labels', () {
    expect(describePronouns(Pronouns.unspecified), 'Not set');
    expect(describePronouns(Pronouns.theyThem), 'they / them');
    expect(describePronouns(Pronouns.sheHer), 'she / her');
    expect(describePronouns(Pronouns.heHim), 'he / him');
  });

  test('example sentence agrees with the chosen pronoun', () {
    expect(
      pronounExampleSentence(Pronouns.theyThem),
      'They log a period, and olf updates their estimate.',
    );
    expect(
      pronounExampleSentence(Pronouns.sheHer),
      'She logs a period, and olf updates her estimate.',
    );
    expect(
      pronounExampleSentence(Pronouns.unspecified),
      pronounExampleSentence(Pronouns.theyThem),
    );
  });

  group('storage round-trip', () {
    test('every value round-trips', () {
      for (final p in Pronouns.values) {
        expect(pronounsFromStorage(pronounsToStorage(p)), p);
      }
    });

    test('unspecified stores empty; junk parses to unspecified', () {
      expect(pronounsToStorage(Pronouns.unspecified), '');
      expect(pronounsFromStorage(null), Pronouns.unspecified);
      expect(pronounsFromStorage('nonsense'), Pronouns.unspecified);
    });
  });
}
