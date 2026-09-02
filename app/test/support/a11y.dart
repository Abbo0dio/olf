import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared accessibility-guideline harness for the p5.1a screen audit.
///
/// One call per top-level screen test. It always enforces
/// [labeledTapTargetGuideline] — every tappable carries a screen-reader label —
/// plus the Android + iOS minimum-tap-target-size guidelines and, since p5.1c,
/// [textContrastGuideline]. All four passed unskipped across every surface at
/// the close of the Phase 5 a11y audit; the systematic both-theme contrast
/// proof over the `ColorScheme` role pairs is `theme_contrast_test.dart`.
/// [tapTargets] / [contrast] stay as opt-outs for a future screen that
/// genuinely needs a follow-up fix — none do today.
Future<void> expectMeetsA11yGuidelines(
  WidgetTester tester, {
  bool tapTargets = true,
  bool contrast = true,
}) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (tapTargets) {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  }
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  handle.dispose();
}

/// A semantics node that is operable (tap / long-press) but announces nothing —
/// the exact defect p5.1a exists to remove.
class UnlabelledTappable {
  UnlabelledTappable(this.rect, this.actions);

  final Rect rect;
  final String actions;

  @override
  String toString() =>
      'operable node with no label/value/tooltip ($actions) at $rect';
}

/// Walk the live semantics tree of every render view and return each operable
/// node that a screen reader would land on with nothing to say. Text fields are
/// exempt (their value, not a label, is the announcement), as are hidden nodes
/// and nodes folded into an ancestor (a `Switch` inside a `SwitchListTile`, a
/// `Radio` inside a `RadioListTile`, …) — the ancestor carries the label.
List<UnlabelledTappable> unlabelledTappables(WidgetTester tester) {
  final offenders = <UnlabelledTappable>[];

  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final operable =
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);
    final flags = data.flagsCollection;
    final announces =
        data.label.trim().isNotEmpty ||
        data.value.trim().isNotEmpty ||
        data.tooltip.trim().isNotEmpty;
    if (operable &&
        !flags.isHidden &&
        !flags.isTextField &&
        !node.isMergedIntoParent &&
        !announces) {
      final actions = <String>[
        if (data.hasAction(SemanticsAction.tap)) 'tap',
        if (data.hasAction(SemanticsAction.longPress)) 'longPress',
      ].join('+');
      offenders.add(UnlabelledTappable(node.rect, actions));
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in RendererBinding.instance.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return offenders;
}

/// The `label / value / hint` of the semantics node that currently holds input
/// focus, joined with ` / ` — `'<none>'` when nothing is focused. Buttons
/// expose their child text here; text fields expose their `InputDecoration`
/// label. Used by the keyboard-traversal tests to name the focused control.
String focusedSemanticToken() {
  String? found;
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (found == null && d.flagsCollection.isFocused) {
      found = [
        d.label,
        d.value,
        d.hint,
      ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' / ');
    }
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  for (final view in RendererBinding.instance.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return (found == null || found!.isEmpty) ? '<none>' : found!;
}

/// Press `Tab` (or `Shift`+`Tab` when [backwards]) until the focused semantics
/// token contains [needle], up to [maxSteps] presses. Returns the matched
/// token, or `null` if it was never focused — a `null` return in a test that
/// expects to reach a control is a keyboard-reachability failure.
///
/// The caller is responsible for an active `tester.ensureSemantics()` handle.
Future<String?> tabToFocus(
  WidgetTester tester,
  Pattern needle, {
  int maxSteps = 40,
  bool backwards = false,
}) async {
  if (backwards) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  try {
    for (var i = 0; i < maxSteps; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final token = focusedSemanticToken();
      if (token != '<none>' && token.contains(needle)) return token;
    }
  } finally {
    if (backwards) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }
  }
  return null;
}

/// Activate the currently-focused control with the keyboard. Enter and Space
/// are the two keys a button / toggle must honour; this sends both (a control
/// that acts on the first is idempotent-safe for the second within one frame
/// only if it navigated away — callers that toggle state should pass
/// [spaceToo] `false`).
Future<void> activateFocused(
  WidgetTester tester, {
  bool spaceToo = true,
}) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  if (spaceToo) await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
}
