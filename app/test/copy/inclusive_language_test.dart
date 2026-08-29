import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// p1.9 copy lint: user-facing strings must stay gender-neutral and
/// non-heteronormative. This scans every string literal under `app/lib` and
/// `core/lib` for phrases we never want to ship ("hey girl", "for women",
/// "he or she", …). See `docs/inclusive-language.md` for the checklist this
/// enforces and how to add an exception.
///
/// It is deliberately blunt: if a genuine, non-copy use of a denied phrase ever
/// appears, add it to [_allowedContexts] with a comment explaining why.
void main() {
  // Word-boundary, case-insensitive. Bare pronouns (her/his/him/he/she) are NOT
  // denied — the app has a legitimate pronoun feature (see pronouns.dart).
  final denied = <RegExp>[
    RegExp(r'\bhey\s+(girl|girlie|lady|ladies)\b', caseSensitive: false),
    RegExp(r'\bgirl(s|ie)?\b', caseSensitive: false),
    RegExp(r'\bgal(s)?\b', caseSensitive: false),
    RegExp(r'\blad(y|ies)\b', caseSensitive: false),
    RegExp(r'\bfor\s+women\b', caseSensitive: false),
    RegExp(
      r'\bwomen[’'
      "'"
      r']?s\s+health\b',
      caseSensitive: false,
    ),
    RegExp(r'\bmenstruating\s+women\b', caseSensitive: false),
    RegExp(r'\b(he|she)\s+or\s+(she|he)\b', caseSensitive: false),
    RegExp(r'\b(his|her)\s+or\s+(her|his)\b', caseSensitive: false),
    RegExp(r'\bhe\s*/\s*she\b', caseSensitive: false),
    RegExp(r'\bs\s*/\s*he\b', caseSensitive: false),
    RegExp(r'\b(boy|girl)friend\b', caseSensitive: false),
    RegExp(r'\b(husband|wife)\b', caseSensitive: false),
    RegExp(r'\baunt\s+flo\b', caseSensitive: false),
    RegExp(r'\btime\s+of\s+the\s+month\b', caseSensitive: false),
    RegExp(r'\bfeminine\s+(hygiene|products?)\b', caseSensitive: false),
    RegExp(r'\b(mom|mum|mother)[- ]to[- ]be\b', caseSensitive: false),
  ];

  // Exact string-literal contents that are allowed to contain an otherwise
  // denied phrase, each with a reason. Keep this list short.
  const allowedContexts = <String>[
    // (none yet)
  ];

  // Matches single- or double-quoted Dart string literals on one line,
  // honouring backslash escapes. Good enough for a copy lint.
  final stringLiteral = RegExp(
    "'((?:[^'\\\\\\n]|\\\\.)*)'"
    r'|"((?:[^"\\\n]|\\\\.)*)"',
  );

  Iterable<File> dartSources(String dir) {
    final root = Directory(dir);
    if (!root.existsSync()) return const [];
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
  }

  test('no gendered or heteronormative copy in app/lib or core/lib', () {
    // Tests run with the CWD at the package root (`app`); `core` is a sibling.
    final roots = <String>['lib', '../core/lib'];
    final violations = <String>[];

    for (final root in roots) {
      for (final file in dartSources(root)) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final m in stringLiteral.allMatches(lines[i])) {
            final content = m.group(1) ?? m.group(2) ?? '';
            if (allowedContexts.contains(content)) continue;
            for (final rule in denied) {
              if (rule.hasMatch(content)) {
                violations.add(
                  '${file.path}:${i + 1}  matches ${rule.pattern}\n    "$content"',
                );
              }
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Gendered / heteronormative copy found. Rephrase to second person '
          '("you") or neutral terms, or add a justified entry to '
          '`allowedContexts` in this test.\n\n${violations.join('\n')}',
    );
  });
}
