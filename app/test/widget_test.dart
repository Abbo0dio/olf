import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

import 'support/harness.dart';

void main() {
  testWidgets('empty state shows the app name and an add affordance', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(find.widgetWithText(AppBar, 'olf'), findsOneWidget);
        expect(find.text('No periods logged yet.'), findsOneWidget);
        expect(find.text('Add a period'), findsOneWidget);
      },
    );
  });

  testWidgets('renders in dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        final context = tester.element(find.text('No periods logged yet.'));
        expect(Theme.of(context).brightness, Brightness.dark);
      },
    );
  });

  testWidgets('missing key → fail-safe screen, no calendar', (tester) async {
    await pumpOlf(
      tester,
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) async => throw const MissingDatabaseKeyException(),
        ),
      ],
      body: () async {
        expect(find.text("Can't unlock your data"), findsOneWidget);
        expect(find.text('Add a period'), findsNothing);
      },
    );
  });
}
