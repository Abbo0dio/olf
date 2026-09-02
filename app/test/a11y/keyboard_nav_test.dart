import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/onboarding/disclaimers.dart';
import 'package:olf_app/src/period/period_format.dart';

import '../support/a11y.dart';
import '../support/harness.dart';

/// p5.1c — every primary action must be reachable **and** activatable with an
/// external keyboard / switch access (Tab / Shift-Tab + Enter / Space), with no
/// keyboard trap. `focus_order_test.dart` already asserts traversal *order* on
/// the onboarding form and the settings list; this file adds keyboard
/// *activation* on three representative shapes — a form, a scrolling list, and
/// a screen whose primary verb is a FloatingActionButton — plus an explicit
/// no-trap check.
void main() {
  testWidgets(
    'form (first-run): the acknowledge button is reachable by Tab and '
    'completes onboarding when activated with the keyboard',
    (tester) async {
      await pumpOlf(
        tester,
        onboarded: false,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          final handle = tester.ensureSemantics();
          final token = await tabToFocus(tester, disclaimerAcknowledgeLabel);
          expect(
            token,
            isNotNull,
            reason:
                'the "$disclaimerAcknowledgeLabel" button was never focused '
                'by Tab',
          );

          await activateFocused(tester, spaceToo: false);

          // Onboarding is dismissed → the home scaffold (with its Settings
          // action) is shown, and the acknowledge button is gone.
          expect(find.text(disclaimerAcknowledgeLabel), findsNothing);
          expect(find.byTooltip('Settings'), findsOneWidget);
          handle.dispose();
        },
      );
    },
  );

  testWidgets(
    'list (settings): a navigation row is reachable by Tab and pushes its '
    'screen when activated with the keyboard',
    (tester) async {
      await pumpOlf(
        tester,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();

          final handle = tester.ensureSemantics();
          final token = await tabToFocus(tester, 'Privacy policy');
          expect(
            token,
            isNotNull,
            reason: 'the "Privacy policy" row was never focused by Tab',
          );

          await activateFocused(tester, spaceToo: false);

          // The row pushed PrivacyPolicyScreen — its AppBar title is showing.
          expect(find.widgetWithText(AppBar, 'Privacy policy'), findsOneWidget);
          handle.dispose();
        },
      );
    },
  );

  testWidgets(
    'FAB (manage symptoms): the FloatingActionButton is reachable by Tab and '
    'opens the add dialog when activated with the keyboard',
    (tester) async {
      await pumpOlf(
        tester,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          final today = DateTime.now();
          // Home → tap today's calendar cell → day sheet → Manage symptoms.
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, no period logged'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Manage symptoms'));
          await tester.pumpAndSettle();

          final handle = tester.ensureSemantics();
          final token = await tabToFocus(tester, 'Add symptom');
          expect(
            token,
            isNotNull,
            reason: 'the "Add symptom" FAB was never focused by Tab',
          );

          await activateFocused(tester, spaceToo: false);

          // The add-symptom dialog is up with a focused text field.
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          handle.dispose();
        },
      );
    },
  );

  testWidgets(
    'no keyboard trap: Tab keeps moving focus through the settings list and '
    'eventually cycles rather than sticking',
    (tester) async {
      await pumpOlf(
        tester,
        overrides: [dbOverride(memoryDb())],
        body: () async {
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();

          final handle = tester.ensureSemantics();
          final visited = <String>[];
          var repeats = 0;
          for (var i = 0; i < 60; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            final token = focusedSemanticToken();
            if (token == '<none>') continue;
            if (visited.contains(token)) {
              repeats++;
            } else {
              visited.add(token);
            }
          }

          // Focus reached several distinct controls (not stuck on one) and
          // came back around (traversal wraps — no trap, no dead end).
          expect(
            visited.length,
            greaterThan(3),
            reason: 'focus barely moved: $visited',
          );
          expect(
            repeats,
            greaterThan(0),
            reason:
                'focus never revisited a control in 60 Tabs — it may be '
                'escaping or stalling rather than cycling: $visited',
          );
          handle.dispose();
        },
      );
    },
  );
}
