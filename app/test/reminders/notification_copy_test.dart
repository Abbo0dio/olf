import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/reminders/notification_copy.dart';
import 'package:olf_core/olf_core.dart';

/// p4.3 lock-in for the strings that can land on a lock screen.
///
/// A reminder notification is visible to anyone holding the phone, so its
/// wording must never reveal *why* olf is installed and must never scold. These
/// checks pin the guarantees the copy in `notification_copy.dart` is written to
/// meet. The p1.9 `inclusive_language_test` scans the same file for gendered /
/// heteronormative phrasing automatically — no wiring needed here.
void main() {
  // Every body that can reach a notification, keyed by kind.
  final bodies = <ReminderKind, String>{
    for (final kind in ReminderKind.values)
      kind: notificationCopyFor(kind).body,
  };

  test('every kind has a non-empty title and body', () {
    for (final kind in ReminderKind.values) {
      final copy = notificationCopyFor(kind);
      expect(copy.title, isNotEmpty, reason: '$kind has an empty title');
      expect(copy.body, isNotEmpty, reason: '$kind has an empty body');
    }
  });

  test('the title is the bare app name for every kind, never the category', () {
    // A per-kind title ("Fertile window", "Late period check-in") would itself
    // expose health state on the lock screen.
    for (final kind in ReminderKind.values) {
      expect(notificationCopyFor(kind).title, 'olf', reason: '$kind');
    }
  });

  test('the medication body is byte-identical to p1.7', () {
    // The medication path is unchanged by p4.3 (orchestrator spec).
    expect(
      notificationCopyFor(ReminderKind.medication).body,
      'Time for your daily check-in.',
    );
  });

  test('no body names a medication, method or device', () {
    // Structural guard: the copy is model-written and carries none of these
    // today, but the check stays so a later edit cannot slip one in.
    const banned = [
      'medication',
      'medicine',
      'med ',
      'pill',
      'patch',
      'the ring',
      'injection',
      'the shot',
      'dose',
      'dosage',
      'tablet',
      'capsule',
      'birth control',
      'contracept',
      'iud',
      'implant',
      'condom',
      'diaphragm',
    ];
    for (final entry in bodies.entries) {
      final text = entry.value.toLowerCase();
      for (final word in banned) {
        expect(
          text.contains(word),
          isFalse,
          reason: '${entry.key} body leaks "$word": "${entry.value}"',
        );
      }
    }
  });

  test('no body names a cycle phase, symptom or other health state', () {
    const banned = [
      'period',
      'menstru',
      'cycle',
      'ovulat',
      'fertil',
      'flow',
      'bleed',
      'spotting',
      'cramp',
      'symptom',
      'mood',
      'temperature',
      'basal',
      'bbt',
      'mucus',
      'discharge',
      'luteal',
      'follicular',
    ];
    for (final entry in bodies.entries) {
      final text = entry.value.toLowerCase();
      for (final word in banned) {
        expect(
          text.contains(word),
          isFalse,
          reason: '${entry.key} body leaks "$word": "${entry.value}"',
        );
      }
    }
  });

  test('no body carries a diagnosis word or "pregnan…"', () {
    const banned = [
      'pregnan',
      'diagnos',
      'pcos',
      'endometrios',
      'miscarriage',
      'menopaus',
      'infertil',
      'disorder',
    ];
    for (final entry in bodies.entries) {
      final text = entry.value.toLowerCase();
      for (final word in banned) {
        expect(
          text.contains(word),
          isFalse,
          reason: '${entry.key} body leaks "$word": "${entry.value}"',
        );
      }
    }
  });

  test('no body scolds, commands or manufactures urgency', () {
    final banned = <RegExp>[
      RegExp(r'\blog it\b', caseSensitive: false),
      RegExp(r"\bdon'?t forget\b", caseSensitive: false),
      RegExp(r'\byou (need|have) to\b', caseSensitive: false),
      RegExp(r'\byou must\b', caseSensitive: false),
      RegExp(r'\byou should\b', caseSensitive: false),
      RegExp(r'\bmake sure\b', caseSensitive: false),
      RegExp(r'\bright now\b', caseSensitive: false),
      RegExp(r'\bas soon as\b', caseSensitive: false),
      RegExp(r'\bnow\b', caseSensitive: false),
      RegExp(r'\basap\b', caseSensitive: false),
      RegExp(r'\boverdue\b', caseSensitive: false),
      RegExp(r'\blate\b', caseSensitive: false),
      RegExp(r'\bhas (your|it|the)\b', caseSensitive: false),
    ];
    for (final entry in bodies.entries) {
      for (final rule in banned) {
        expect(
          rule.hasMatch(entry.value),
          isFalse,
          reason: '${entry.key} body matches ${rule.pattern}: "${entry.value}"',
        );
      }
    }
  });

  test('no body poses a question or shouts', () {
    for (final entry in bodies.entries) {
      expect(
        entry.value.contains('?'),
        isFalse,
        reason: '${entry.key} body asks a question: "${entry.value}"',
      );
      expect(
        entry.value.contains('!'),
        isFalse,
        reason: '${entry.key} body uses "!": "${entry.value}"',
      );
    }
  });

  test('no body uses a gendered second-person term', () {
    // Belt-and-braces alongside the p1.9 lint, scoped to just these strings.
    final gendered = <RegExp>[
      RegExp(
        r'\b(girl|girlie|gal|lady|ladies|sis|sista|mama|momma|mom|mum)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(wo)?m[ae]n\b', caseSensitive: false),
      RegExp(
        r'\b(she|her|hers|herself|he|him|his|himself)\b',
        caseSensitive: false,
      ),
    ];
    for (final entry in bodies.entries) {
      for (final rule in gendered) {
        expect(
          rule.hasMatch(entry.value),
          isFalse,
          reason: '${entry.key} body matches ${rule.pattern}: "${entry.value}"',
        );
      }
    }
  });

  test('every body is short enough to read at a glance on a lock screen', () {
    for (final entry in bodies.entries) {
      expect(
        entry.value.length,
        lessThanOrEqualTo(90),
        reason:
            '${entry.key} body is ${entry.value.length} chars: '
            '"${entry.value}"',
      );
    }
  });

  test('the late check-in body invites rather than interrogates', () {
    // Orchestrator spec: "invitational, not interrogative" — it offers, it does
    // not collect homework.
    final body = notificationCopyFor(ReminderKind.latePeriodCheckIn).body;
    expect(body.contains('?'), isFalse);
    expect(body.toLowerCase(), contains('when you'));
    expect(body.toLowerCase(), isNot(contains('started')));
  });
}
