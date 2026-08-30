import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/onboarding/disclaimers.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  group(
    'policy content (reviewed against requirements.md §3 / §6, MHMDA/SB370)',
    () {
      final allText = [
        privacyPolicyIntro,
        privacyPolicyLastUpdated,
        privacyChoicesHeading,
        privacyChoicesIntro,
        analyticsOptInLabel,
        analyticsOptInHint,
        dataSharingOptInLabel,
        dataSharingOptInHint,
        privacyChoicesFootnote,
        for (final (h, b) in privacyPolicySections) '$h $b',
      ].join('\n');

      test('every commitment has a distinct, non-empty heading and body', () {
        final headings = privacyPolicySections.map((s) => s.$1).toList();
        expect(headings.toSet(), hasLength(headings.length));
        for (final (heading, body) in privacyPolicySections) {
          expect(heading.trim(), isNotEmpty);
          expect(body.trim().length, greaterThan(20));
        }
      });

      test('carries the explicit commitments', () {
        expect(allText, contains('never sell'));
        expect(allText, contains('valid legal process'));
        expect(allText.toLowerCase(), contains('nothing for us to hand over'));
        expect(allText, contains('this device only'));
        expect(allText, contains('no third-party tracking or advertising'));
      });

      test('names the consumer-health-privacy laws it aligns with', () {
        expect(allText, contains('My Health My Data Act'));
        expect(allText, contains('Nevada SB370'));
      });

      test('both consent choices are described as off by default', () {
        expect(allText.toLowerCase(), contains('off by default'));
        expect(
          analyticsOptInHint.toLowerCase(),
          contains('nothing is collected'),
        );
        expect(dataSharingOptInHint.toLowerCase(), contains('shares nothing'));
      });

      test('"last reviewed" line carries a four-digit year', () {
        expect(privacyPolicyLastUpdated, matches(RegExp(r'\b\d{4}\b')));
      });
    },
  );

  testWidgets('reachable from Settings → Privacy, and shows the policy', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ListTile, privacyPolicyTitle));
        await tester.pumpAndSettle();

        expect(find.text(privacyPolicyTitle), findsOneWidget); // the AppBar
        expect(find.textContaining('valid legal process'), findsOneWidget);
        expect(find.text(privacyChoicesHeading), findsOneWidget);
      },
    );
  });

  testWidgets('reachable from the first-run screen', (tester) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.text(disclaimerTitle), findsOneWidget);

        await tester.tap(find.text(privacyPolicyFirstRunLink));
        await tester.pumpAndSettle();

        expect(find.text(privacyPolicyTitle), findsOneWidget);
        expect(find.textContaining('never sell'), findsOneWidget);
      },
    );
  });

  testWidgets('both opt-ins default off and toggle independently, persisting', (
    tester,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, privacyPolicyTitle));
        await tester.pumpAndSettle();

        final analytics = find.widgetWithText(
          SwitchListTile,
          analyticsOptInLabel,
        );
        final sharing = find.widgetWithText(
          SwitchListTile,
          dataSharingOptInLabel,
        );
        expect(tester.widget<SwitchListTile>(analytics).value, isFalse);
        expect(tester.widget<SwitchListTile>(sharing).value, isFalse);

        await tester.tap(analytics);
        await flush(tester, 20);

        expect(await settings.get(SettingKeys.analyticsOptIn), 'true');
        expect(await settings.get(SettingKeys.dataSharingOptIn), isNull);
        expect(tester.widget<SwitchListTile>(analytics).value, isTrue);
        expect(tester.widget<SwitchListTile>(sharing).value, isFalse);

        // Turning it back off persists 'false' and takes effect at once.
        await tester.tap(analytics);
        await flush(tester, 20);
        expect(await settings.get(SettingKeys.analyticsOptIn), 'false');
        expect(tester.widget<SwitchListTile>(analytics).value, isFalse);
      },
    );
  });
}
