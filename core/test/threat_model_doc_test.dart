import 'dart:io';

import 'package:test/test.dart';

/// Guard for `docs/threat-model.md` (p2.8). The threat model is a *living*
/// document — it has to be walked and re-signed at every phase gate — so this
/// test fails the build if the file goes missing, loses a required section or
/// its data-flow diagram.
///
/// The per-phase currency check (the Review log must name the current phase)
/// used to be enforced here by parsing `**Status:**` lines out of the old
/// `DEVELOPMENT_PLAN.md`. Task status is no longer in a versioned file — it
/// lives in `.herdsman/state.md` (Orchestrator-only) — so that
/// check moved to the Orchestrator's manual phase-close gate (herdsman
/// `orchestrator/phase-loop.md`, "Phase close").
///
/// It is a plain `dart:io` test picked up by the existing `core — unit tests`
/// step in CI (same wiring as `dependency_audit_test.dart`); no workflow change.
/// `dart test` runs with `core/` as CWD, so the repo root is one level up.
void main() {
  final doc = File('../docs/threat-model.md');

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
}
