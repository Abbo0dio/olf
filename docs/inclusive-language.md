# Inclusive language

`requirements.md` §4 and §9(7): olf is for **anyone with a cycle**. The default experience is
neutral, non-pink, non-gendered, and never assumes a partner's gender. Copy is written in the
second person ("you", "your cycle") and only uses gendered pronouns where the reader has
explicitly chosen them (Settings → Pronouns; stored as `SettingKeys.pronouns`).

This is enforced two ways: the checklist below for humans, and a blunt lint —
[`app/test/copy/inclusive_language_test.dart`](../app/test/copy/inclusive_language_test.dart) —
that scans every string literal under `app/lib` and `core/lib` and fails the build on a denied
phrase. It runs in the normal `test` job (part of the required `CI OK` check).

## Checklist for any user-facing string

- [ ] **Second person, not gendered nouns.** "your period", "when you last logged" — never
      "her period", "girl", "lady", "gal".
- [ ] **No "for women" framing.** Not "period tracker for women", "women's health",
      "menstruating women". It's "your cycle".
- [ ] **Partners are ungendered.** "your partner" — never "boyfriend", "girlfriend",
      "husband", "wife".
- [ ] **No "he or she" / "he/she" / "s/he".** Use "they", or rewrite in the second person.
- [ ] **No euphemisms that carry a gender.** "Aunt Flo", "that time of the month",
      "feminine hygiene/products".
- [ ] **No "mom-to-be" / "mother-to-be"** in pregnancy or loss copy — "if you're pregnant".
- [ ] **Pronoun feature copy is exempt by design.** `core/lib/src/personalization/pronouns.dart`
      legitimately contains the strings `she`, `her`, `he`, `him`, `they`, `them` and the
      example sentence. Bare pronouns are **not** on the denylist for this reason.
- [ ] **Dark mode.** The string reads correctly against both `olfTheme(light)` and
      `olfTheme(dark)` (colours come from the `ColorScheme`, never hard-coded).

## The lint

Denied phrases are word-boundary, case-insensitive regexes in the test's `denied` list
(see the file for the current set). It inspects **string literals only**, so identifiers and
comments are not flagged.

### If it flags a legitimate, non-copy use

Add the exact literal to `allowedContexts` in the test with a one-line comment explaining why,
and note it in the PR description. Prefer rewording over an exception.

### Adding a phrase

Add a regex to `denied` in the test. New rules are routine; keep them specific enough that
they only match user-facing copy.

## Not covered

- Strings built at runtime by concatenation or interpolation from non-literal parts.
- Asset text (images, PDFs), platform store listings, and this repo's own docs.
- Tone and framing beyond the phrase list — that's a review concern.
