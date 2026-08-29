/// The user's pronouns, for copy that refers to them in the third person
/// (p1.9). Kept in `core` so any consumer — the app now, a desktop shell later —
/// formats sentences the same way.
///
/// [Pronouns.unspecified] is the default and resolves to they/them via
/// [formsFor], so untouched copy reads correctly for everyone.
library;

/// The pronoun sets olf offers. `unspecified` means the user has not chosen.
enum Pronouns { unspecified, sheHer, theyThem, heHim }

/// The grammatical forms of a pronoun set, ready to drop into a sentence.
///
/// Example (they/them): "**They** logged a period. olf reminded **them**. It is
/// **their** cycle; the entry is **theirs**. They can see it for **themself**."
class PronounForms {
  const PronounForms({
    required this.subject,
    required this.object,
    required this.possessiveDeterminer,
    required this.possessivePronoun,
    required this.reflexive,
    required this.pluralVerbs,
  });

  /// "they" / "she" / "he"
  final String subject;

  /// "them" / "her" / "him"
  final String object;

  /// "their" / "her" / "his"
  final String possessiveDeterminer;

  /// "theirs" / "hers" / "his"
  final String possessivePronoun;

  /// "themself" / "herself" / "himself"
  final String reflexive;

  /// `true` when [subject] takes a plural verb ("they log", vs "she logs").
  final bool pluralVerbs;

  /// [subject] with its first letter upper-cased, for sentence starts.
  String get subjectCapitalized => subject.isEmpty
      ? subject
      : subject[0].toUpperCase() + subject.substring(1);

  /// "log" → "log" for they, "logs" for she/he.
  String verb(String base) => pluralVerbs ? base : '${base}s';
}

const PronounForms _theyThem = PronounForms(
  subject: 'they',
  object: 'them',
  possessiveDeterminer: 'their',
  possessivePronoun: 'theirs',
  reflexive: 'themself',
  pluralVerbs: true,
);

/// The [PronounForms] for [pronouns]. [Pronouns.unspecified] resolves to
/// they/them.
PronounForms formsFor(Pronouns pronouns) => switch (pronouns) {
  Pronouns.unspecified || Pronouns.theyThem => _theyThem,
  Pronouns.sheHer => const PronounForms(
    subject: 'she',
    object: 'her',
    possessiveDeterminer: 'her',
    possessivePronoun: 'hers',
    reflexive: 'herself',
    pluralVerbs: false,
  ),
  Pronouns.heHim => const PronounForms(
    subject: 'he',
    object: 'him',
    possessiveDeterminer: 'his',
    possessivePronoun: 'his',
    reflexive: 'himself',
    pluralVerbs: false,
  ),
};

/// A short menu label, e.g. `they / them`. `unspecified` is `Not set`.
String describePronouns(Pronouns pronouns) => switch (pronouns) {
  Pronouns.unspecified => 'Not set',
  Pronouns.sheHer => 'she / her',
  Pronouns.theyThem => 'they / them',
  Pronouns.heHim => 'he / him',
};

/// A one-line example so the user can see how their choice reads in copy. This
/// is the first concrete consumer of the setting (p1.9); later phases with
/// third-person sentence copy use [formsFor] the same way.
String pronounExampleSentence(Pronouns pronouns) {
  final f = formsFor(pronouns);
  return '${f.subjectCapitalized} ${f.verb('log')} a period, and olf updates '
      '${f.possessiveDeterminer} estimate.';
}

/// Serialise for `app_settings`. `unspecified` stores as an empty string so it
/// round-trips to the same default.
String pronounsToStorage(Pronouns pronouns) =>
    pronouns == Pronouns.unspecified ? '' : pronouns.name;

/// Parse back from `app_settings`. Anything unrecognised (incl. `null` / empty)
/// is [Pronouns.unspecified].
Pronouns pronounsFromStorage(String? value) {
  for (final p in Pronouns.values) {
    if (p != Pronouns.unspecified && p.name == value) return p;
  }
  return Pronouns.unspecified;
}
