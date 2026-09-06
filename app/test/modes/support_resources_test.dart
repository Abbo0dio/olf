import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/support_resources_content.dart';
import 'package:olf_app/src/modes/support_resources_screen.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  Widget host(PregnancyEndKind kind) => MaterialApp(
    theme: olfTheme(Brightness.light),
    home: SupportResourcesScreen(kind: kind),
  );

  testWidgets('loss content is shown for a loss', (tester) async {
    await tester.pumpWidget(host(PregnancyEndKind.loss));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'After a loss'), findsOneWidget);
    expect(find.textContaining('Grief, relief, numbness'), findsOneWidget);
    // birth-only copy must not leak in
    expect(find.textContaining('chest- or breastfeeding'), findsNothing);
  });

  testWidgets('birth content is shown for a birth', (tester) async {
    await tester.pumpWidget(host(PregnancyEndKind.birth));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'After a birth'), findsOneWidget);
    expect(find.textContaining('chest- or breastfeeding'), findsOneWidget);
    expect(find.textContaining('Grief, relief, numbness'), findsNothing);
  });

  testWidgets('every variant carries the disclaimer and a real-care line', (
    tester,
  ) async {
    for (final kind in PregnancyEndKind.values) {
      await tester.pumpWidget(host(kind));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('doctor'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('doctor'),
        findsWidgets,
        reason: '$kind is missing a pointer to real care',
      );

      await tester.scrollUntilVisible(
        find.text(SupportResources.notMedicalDeviceLine),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(SupportResources.notMedicalDeviceLine),
        findsOneWidget,
        reason: '$kind is missing the not-a-medical-device line',
      );
    }
  });

  test('no bundled resource text contains a phone-home URL', () {
    for (final kind in PregnancyEndKind.values) {
      final c = supportResourcesFor(kind);
      final blob = [
        c.title,
        c.intro,
        c.findCareLine,
        for (final s in c.sections) '${s.heading} ${s.body}',
      ].join(' ');
      expect(blob.contains('http'), isFalse, reason: '$kind has a URL');
      expect(blob.contains('www.'), isFalse, reason: '$kind has a URL');
    }
  });
}
