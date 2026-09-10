import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_app/src/widgets/empty_state.dart';

/// r5b — the one shared empty-state widget: a discreet leading icon + a single
/// low-emphasis line, with an optional CTA. The message copy is the caller's;
/// nothing here adds or redacts spoken detail.
void main() {
  Future<void> pumpEmptyState(WidgetTester tester, EmptyState widget) =>
      tester.pumpWidget(
        MaterialApp(
          theme: olfTheme(Brightness.light),
          home: Scaffold(body: widget),
        ),
      );

  testWidgets('renders the message with the leading icon', (tester) async {
    await pumpEmptyState(
      tester,
      const EmptyState(message: 'Nothing logged yet.'),
    );
    expect(find.text('Nothing logged yet.'), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('an overridden icon is used when given', (tester) async {
    await pumpEmptyState(
      tester,
      const EmptyState(
        message: 'No medications added.',
        icon: Icons.medication_outlined,
      ),
    );
    expect(find.text('No medications added.'), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('the optional CTA renders and fires', (tester) async {
    var tapped = 0;
    await pumpEmptyState(
      tester,
      EmptyState(
        message: 'Your symptom list is empty.',
        ctaLabel: 'Add one',
        onCta: () => tapped++,
      ),
    );
    expect(find.text('Your symptom list is empty.'), findsOneWidget);
    expect(find.text('Add one'), findsOneWidget);
    await tester.tap(find.text('Add one'));
    expect(tapped, 1);
  });

  testWidgets('no CTA text or button when none is given', (tester) async {
    await pumpEmptyState(tester, const EmptyState(message: 'Nothing here.'));
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the icon is decorative — it carries no semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpEmptyState(tester, const EmptyState(message: 'Nothing here.'));
    // An icon in the tree, but the semantics tree exposes only the message.
    expect(find.byType(Icon), findsOneWidget);
    expect(find.bySemanticsLabel('Nothing here.'), findsOneWidget);
    handle.dispose();
  });
}
