import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/main.dart';

void main() {
  testWidgets('home screen renders the app name and empty-state copy', (
    tester,
  ) async {
    await tester.pumpWidget(const OlfApp());

    expect(find.widgetWithText(AppBar, 'olf'), findsOneWidget);
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('renders in dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const OlfApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(
      find.text('Nothing logged yet.'),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
