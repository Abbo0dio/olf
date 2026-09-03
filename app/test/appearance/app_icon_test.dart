import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/appearance/app_icon.dart';

import '../support/harness.dart';

/// p5.4 — the Settings → Appearance "App icon" row. Picking an option asks the
/// [AppIconRepository] seam first and only persists once it succeeds; a failed
/// switch surfaces a calm message and leaves the stored choice untouched.
void main() {
  group('AppIconOption.fromStorage', () {
    test('defaults to branded for absent / unknown values', () {
      expect(AppIconOption.fromStorage(null), AppIconOption.branded);
      expect(AppIconOption.fromStorage(''), AppIconOption.branded);
      expect(AppIconOption.fromStorage('nonsense'), AppIconOption.branded);
    });

    test('round-trips every option id', () {
      for (final o in AppIconOption.values) {
        expect(AppIconOption.fromStorage(o.id), o);
      }
    });
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Finder appIconRow() => find.widgetWithText(ListTile, 'App icon');

  testWidgets('default is branded — the row reads "Default"', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await openSettings(tester);
        await tester.scrollUntilVisible(appIconRow(), 200);
        expect(
          find.descendant(of: appIconRow(), matching: find.text('Default')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('picking "Notes" calls the seam and persists once it succeeds', (
    tester,
  ) async {
    final icons = FakeAppIconRepository();
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        appIconRepositoryProvider.overrideWithValue(icons),
      ],
      body: () async {
        await openSettings(tester);
        await tester.scrollUntilVisible(appIconRow(), 200);

        await tester.tap(appIconRow());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();

        // Android warns that the app will close before applying.
        expect(find.text('olf will close'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Change icon'));
        await flush(tester);

        expect(icons.last, AppIconOption.notes);
        // The stored value came back through the settings stream.
        expect(
          find.descendant(of: appIconRow(), matching: find.text('Notes')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('a failed switch shows the message and does NOT persist', (
    tester,
  ) async {
    final icons = FakeAppIconRepository(
      failWith: "Couldn't change the app icon. The current icon is unchanged.",
    );
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        appIconRepositoryProvider.overrideWithValue(icons),
      ],
      body: () async {
        await openSettings(tester);
        await tester.scrollUntilVisible(appIconRow(), 200);

        await tester.tap(appIconRow());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Change icon'));
        await flush(tester);

        expect(
          find.text(
            "Couldn't change the app icon. The current icon is unchanged.",
          ),
          findsOneWidget,
        );
        // Still on the default — nothing was written.
        expect(
          find.descendant(of: appIconRow(), matching: find.text('Default')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('cancelling the "will close" warning changes nothing', (
    tester,
  ) async {
    final icons = FakeAppIconRepository();
    await pumpOlf(
      tester,
      overrides: [
        dbOverride(memoryDb()),
        appIconRepositoryProvider.overrideWithValue(icons),
      ],
      body: () async {
        await openSettings(tester);
        await tester.scrollUntilVisible(appIconRow(), 200);

        await tester.tap(appIconRow());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notes'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await flush(tester);

        expect(icons.calls, isEmpty);
        expect(
          find.descendant(of: appIconRow(), matching: find.text('Default')),
          findsOneWidget,
        );
      },
    );
  });
}
