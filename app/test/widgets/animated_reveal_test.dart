import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_app/src/widgets/animated_reveal.dart';

/// r5b — AnimatedReveal: the subtle size + fade wrapper for conditional home
/// cards, gated on the platform reduce-motion flag.
///
/// * Motion on (default): the child renders inside an [AnimatedSize] (plus a
///   fade), and a child swap settles on the new content.
/// * Reduce-motion on: **no animation widgets are mounted at all** and sizes
///   jump straight to their final value.
void main() {
  Future<void> pumpTree(WidgetTester tester, Widget body) => tester.pumpWidget(
    MaterialApp(
      theme: olfTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: body)),
    ),
  );

  Widget card(String label) => Semantics(
    label: label,
    child: Card(child: Text(label)),
  );

  Widget box(double height) =>
      SizedBox(key: ValueKey('box-$height'), width: 200, height: height);

  void useReduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('motion on: the child renders inside AnimatedSize', (
    tester,
  ) async {
    await pumpTree(tester, AnimatedReveal(child: card('A')));
    expect(find.text('A'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AnimatedReveal),
        matching: find.byType(AnimatedSize),
      ),
      findsOneWidget,
    );
  });

  testWidgets('motion on: a swap settles on the new child', (tester) async {
    await pumpTree(tester, AnimatedReveal(child: card('A')));
    await pumpTree(tester, AnimatedReveal(child: card('B')));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('motion on: collapsing to the empty state settles at zero size', (
    tester,
  ) async {
    await pumpTree(tester, AnimatedReveal(child: box(120)));
    await pumpTree(tester, AnimatedReveal(child: null));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnimatedReveal)).height, 0);
  });

  testWidgets('reduce-motion on: no animation widgets are mounted', (
    tester,
  ) async {
    useReduceMotion(tester);
    await pumpTree(tester, AnimatedReveal(child: card('A')));
    // The container stays, but nothing animated does — sizes jump straight.
    expect(find.byType(AnimatedSize), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('reduce-motion on: a swap jumps straight to the final size', (
    tester,
  ) async {
    useReduceMotion(tester);
    await pumpTree(tester, AnimatedReveal(child: box(120)));
    expect(tester.getSize(find.byType(AnimatedReveal)).height, 120);

    await pumpTree(tester, AnimatedReveal(child: box(30)));
    // One frame after the swap — with no animation it is already 30px; an
    // interpolating size animation would still be between 120 and 30 here.
    await tester.pump();
    expect(
      tester.getSize(find.byType(AnimatedReveal)).height,
      30,
      reason: 'with reduce motion the size must jump straight, not animate',
    );
  });
}
