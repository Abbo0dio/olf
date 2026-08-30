import 'dart:io';

import 'package:test/test.dart';

/// Guard for `docs/threat-model.md` (p2.8). The threat model is a *living*
/// document — it has to be walked and re-signed at every phase gate — so this
/// test fails the build if the file goes missing, loses a required section or
/// its data-flow diagram, or does not carry a Review-log entry for the current
/// phase.
///
/// It is a plain `dart:io` test picked up by the existing `core — unit tests`
/// step in CI (same wiring as `dependency_audit_test.dart`); no workflow change.
/// `dart test` runs with `core/` as CWD, so the repo root is one level up.
void main() {
  final doc = File('../docs/threat-model.md');
  final plan = File('../DEVELOPMENT_PLAN.md');

  late String text;

  setUpAll(() {
    expect(
      doc.existsSync(),
      isTrue,
      reason: 'docs/threat-model.md is missing (run from core/)',
    );
    text = doc.readAsStringSync();
  });

  test('is a real document, not a stub', () {
    expect(text.length, greaterThan(2000), reason: 'threat model looks empty');
  });

  test('has every required section heading', () {
    const required = [
      '## Assets',
      '## Adversaries',
      '## Trust boundaries',
      '## Data flow',
      '## Mitigations',
      '## Review log',
    ];
    for (final heading in required) {
      expect(
        text,
        contains(heading),
        reason: 'threat model is missing the "$heading" section',
      );
    }
  });

  test('carries a committed data-flow diagram (Mermaid)', () {
    expect(
      text,
      contains('```mermaid'),
      reason: 'the Data flow section must contain a fenced ```mermaid``` block',
    );
  });

  test('cross-references Phase 0-2 slices in the Mitigations table', () {
    // A spot-check that the mitigation map is actually filled in, not just a
    // header — at least one control from each phase must be named.
    for (final slice in ['p0.', 'p1.', 'p2.']) {
      expect(
        text,
        contains(slice),
        reason: 'Mitigations must cross-reference a $slice.x slice',
      );
    }
  });

  test('the Review log names the current phase', () {
    expect(plan.existsSync(), isTrue, reason: 'DEVELOPMENT_PLAN.md not found');
    final currentPhase = _currentPhase(plan.readAsStringSync());
    expect(
      currentPhase,
      isNotNull,
      reason: 'could not determine the current phase from DEVELOPMENT_PLAN.md',
    );

    final reviewLog = text.substring(text.indexOf('## Review log'));
    expect(
      reviewLog,
      contains('Phase $currentPhase'),
      reason:
          'the Review log has no entry for Phase $currentPhase — the threat '
          'model must be re-reviewed and logged at each phase gate',
    );
  });
}

/// The highest-numbered `### Phase N` in the plan whose `**Status:**` line is
/// not still `TODO`.
int? _currentPhase(String plan) {
  final lines = plan.split('\n');
  final heading = RegExp(r'^### Phase (\d+) ');
  int? current;
  for (var i = 0; i < lines.length; i++) {
    final m = heading.firstMatch(lines[i]);
    if (m == null) continue;
    final n = int.parse(m.group(1)!);
    // The status line is the next non-blank line starting with **Status:**.
    for (var j = i + 1; j < lines.length && j < i + 6; j++) {
      if (!lines[j].startsWith('**Status:**')) continue;
      if (!lines[j].contains('TODO')) {
        current = (current == null || n > current) ? n : current;
      }
      break;
    }
  }
  return current;
}
