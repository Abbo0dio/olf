import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/onboarding/disclaimers.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';

import '../support/a11y.dart';
import '../support/harness.dart';

/// p5.1a — keyboard / switch traversal must follow reading order. These tests
/// tab through a form with a hardware key and record the visited controls, so a
/// future change that reorders the widget tree (or drops an explicit sort key)
/// is caught. The onboarding flow and the settings list are the two required
/// forms in the slice spec; the calendar and FAB+list screens rely on default
/// geometry order, asserted lightly here via the settings list.
void main() {
  Future<List<String>> tabThrough(WidgetTester tester, {int steps = 14}) async {
    final handle = tester.ensureSemantics();
    final seen = <String>[];
    for (var i = 0; i < steps; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final token = focusedSemanticToken();
      if (token == '<none>') continue;
      if (seen.isNotEmpty && seen.last == token) break; // wrapped / stuck
      seen.add(token);
    }
    handle.dispose();
    return seen;
  }

  int firstMatch(List<String> tokens, Pattern needle) =>
      tokens.indexWhere((t) => t.contains(needle));

  testWidgets('first-run: privacy-policy link comes before the acknowledge '
      'button in tab order', (tester) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        final order = await tabThrough(tester);
        final link = firstMatch(order, privacyPolicyFirstRunLink);
        final ack = firstMatch(order, disclaimerAcknowledgeLabel);
        expect(
          link,
          isNonNegative,
          reason: 'policy link never focused: $order',
        );
        expect(ack, isNonNegative, reason: 'ack button never focused: $order');
        expect(link, lessThan(ack), reason: order.toString());
      },
    );
  });

  testWidgets('first-run: with a PIN chosen, PIN → Confirm → acknowledge', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.text(disclaimerPinOptInLabel));
        await tester.pumpAndSettle();

        final order = await tabThrough(tester);
        // Both PIN fields render a label Text ("PIN" / "Confirm PIN") inside
        // the focused subtree alongside the EditableText marker.
        final pin = firstMatch(order, 'PIN');
        final confirm = firstMatch(order, 'Confirm PIN');
        final ack = firstMatch(order, disclaimerAcknowledgeLabel);
        expect(pin, isNonNegative, reason: order.toString());
        expect(confirm, greaterThan(pin), reason: order.toString());
        expect(ack, greaterThan(confirm), reason: order.toString());
      },
    );
  });

  testWidgets('settings: tab order runs top-to-bottom (Appearance → Pronouns '
      '→ Privacy)', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        final order = await tabThrough(tester, steps: 16);
        // Appearance segmented control shows the ThemeMode labels; Pronouns
        // shows describePronouns(...) text; Privacy shows "App lock (PIN)".
        final appearance = firstMatch(order, RegExp('System|Light|Dark'));
        final privacy = firstMatch(order, 'App lock (PIN)');
        expect(appearance, isNonNegative, reason: order.toString());
        expect(privacy, isNonNegative, reason: order.toString());
        expect(appearance, lessThan(privacy), reason: order.toString());
      },
    );
  });
}
