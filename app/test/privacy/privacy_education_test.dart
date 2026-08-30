import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/privacy/privacy_education_content.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';

import '../support/harness.dart';

void main() {
  group(
    'explainer content (reviewed against §3 / §9(8); tone §4 / §9(12))',
    () {
      test(
        'there are exactly three, with distinct non-empty titles/summaries',
        () {
          expect(privacyExplainers, hasLength(3));
          final titles = privacyExplainers.map((e) => e.title).toList();
          final ids = privacyExplainers.map((e) => e.id).toList();
          expect(titles.toSet(), hasLength(3));
          expect(ids.toSet(), hasLength(3));
          for (final e in privacyExplainers) {
            expect(e.title.trim(), isNotEmpty);
            expect(e.summary.trim(), isNotEmpty);
            expect(e.body, isNotEmpty);
            expect(e.body.every((p) => p.trim().length > 30), isTrue);
          }
        },
      );

      test('HIPAA-gap explainer makes the key points', () {
        final text = hipaaGapExplainer.body.join('\n');
        expect(text, contains('covered entities'));
        expect(text, contains('no account and nothing on a server'));
        expect(text, contains('My Health My Data Act'));
        expect(text, contains('Nevada SB370'));
        expect(text.toLowerCase(), contains('does not depend on hipaa'));
      });

      test('law-enforcement explainer makes the key points', () {
        final text = lawEnforcementExplainer.body.join('\n');
        expect(text, contains('valid legal process'));
        expect(text.toLowerCase(), contains('no such data is held'));
        expect(text, contains('decoy'));
        expect(text.toLowerCase(), contains('auto-delete'));
        expect(text.toLowerCase(), contains('not legal advice'));
      });

      test(
        'delete explainer gives concrete, ordered steps ending in uninstall',
        () {
          expect(deleteEverythingSteps, hasLength(3));
          expect(deleteEverythingSteps[0], contains('Backup & restore'));
          expect(deleteEverythingSteps[1], contains('Auto-delete old entries'));
          expect(deleteEverythingSteps[2].toLowerCase(), contains('uninstall'));
          expect(
            deleteEverythingSteps[2].toLowerCase(),
            contains('nothing recoverable'),
          );
          expect(deleteEverythingBackupAction, contains('Backup & restore'));
        },
      );

      test('tone stays calm — no fear-mongering vocabulary', () {
        final all = [
          privacyEducationIntro,
          for (final e in privacyExplainers)
            '${e.title} ${e.summary} '
                '${e.body.join(' ')}',
          deleteEverythingSteps.join(' '),
        ].join('\n').toLowerCase();
        for (final banned in const [
          'panic',
          'terrifying',
          'nightmare',
          'disaster',
          'catastroph',
          'doom',
          'scary',
        ]) {
          expect(
            all,
            isNot(contains(banned)),
            reason: 'alarmist word "$banned"',
          );
        }
      });
    },
  );

  testWidgets('reachable from Settings → Privacy basics, lists all three', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(ListTile, privacyEducationEntryLabel),
        );
        await tester.pumpAndSettle();

        for (final e in privacyExplainers) {
          expect(find.text(e.title), findsOneWidget);
        }
      },
    );
  });

  testWidgets('reachable from the privacy policy screen', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, privacyPolicyTitle));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.widgetWithText(ListTile, privacyEducationEntryLabel),
          200,
        );
        await tester.tap(
          find.widgetWithText(ListTile, privacyEducationEntryLabel),
        );
        await tester.pumpAndSettle();

        expect(find.text(privacyEducationTitle), findsOneWidget);
      },
    );
  });

  testWidgets('the delete explainer hands off to the real backup screen', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ListTile, privacyEducationEntryLabel),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(deleteEverythingExplainer.title));
        await tester.pumpAndSettle();

        // The numbered steps render, then the hand-off button.
        expect(find.textContaining('uninstall olf'), findsOneWidget);
        await tester.tap(find.text(deleteEverythingBackupAction));
        await tester.pumpAndSettle();

        // We are now on the real Backup & restore screen.
        expect(find.text('Create an encrypted backup'), findsOneWidget);
      },
    );
  });

  testWidgets('each explainer opens with its title and a body paragraph', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ListTile, privacyEducationEntryLabel),
        );
        await tester.pumpAndSettle();

        for (final e in privacyExplainers) {
          await tester.tap(find.text(e.title));
          await tester.pumpAndSettle();
          expect(find.text(e.body.first), findsOneWidget);
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
      },
    );
  });
}
