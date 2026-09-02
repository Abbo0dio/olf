import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared accessibility-guideline harness for the p5.1a screen audit.
///
/// One call per top-level screen test. It always enforces
/// [labeledTapTargetGuideline] — every tappable carries a screen-reader label —
/// which is this slice's floor, plus the Android + iOS minimum-tap-target-size
/// guidelines (the existing UI already meets them). [contrast] wraps
/// [textContrastGuideline]; the systematic WCAG contrast sweep across *both*
/// themes is p5.1c's deliverable, so a screen test MAY pass `contrast: false`
/// and leave a `// p5.1c:` marker. [tapTargets] can likewise be turned off with
/// a marker if a future screen genuinely needs a p5.1c size fix — none do today.
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
