import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/security/privacy_shield.dart';

import '../support/harness.dart';

void main() {
  final cover = find.byKey(privacyShieldCoverKey);

  // AppLifecycleListener only allows steps along this chain, in either
  // direction — so walk it one state at a time to reach [target].
  const chain = <AppLifecycleState>[
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  var current = AppLifecycleState.resumed;
  setUp(() => current = AppLifecycleState.resumed);

  Future<void> setLifecycle(
    WidgetTester tester,
    AppLifecycleState target,
  ) async {
    var i = chain.indexOf(current);
    final end = chain.indexOf(target);
    while (i != end) {
      i += i < end ? 1 : -1;
      current = chain[i];
      tester.binding.handleAppLifecycleStateChanged(current);
      await tester.pump();
    }
  }

  testWidgets('the capture block is engaged on start and released on teardown', (
    tester,
  ) async {
    final security = FakeScreenSecurity();

    await pumpOlf(
      tester,
      screenSecurity: security,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(security.calls, contains(true));
        expect(security.last, isTrue);
      },
    );

    // pumpOlf tears the tree down inside the body's `addTearDown`; by here the
    // shield has been disposed and should have released the block.
    expect(security.calls.last, isFalse);
  });

  testWidgets('the mask covers the app whenever it is not resumed', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        expect(cover, findsNothing);
        expect(find.text('No periods logged yet.'), findsOneWidget);

        await setLifecycle(tester, AppLifecycleState.inactive);
        expect(cover, findsOneWidget);
        // The real screen stays mounted behind the cover — state is preserved.
        expect(find.text('No periods logged yet.'), findsOneWidget);

        await setLifecycle(tester, AppLifecycleState.resumed);
        expect(cover, findsNothing);

        await setLifecycle(tester, AppLifecycleState.paused);
        expect(cover, findsOneWidget);

        await setLifecycle(tester, AppLifecycleState.hidden);
        expect(cover, findsOneWidget);

        await setLifecycle(tester, AppLifecycleState.resumed);
        expect(cover, findsNothing);
      },
    );
  });

  testWidgets('the mask is opaque and shows no content', (tester) async {
    await pumpOlf(
      tester,
      overrides: [dbOverride(memoryDb())],
      body: () async {
        await setLifecycle(tester, AppLifecycleState.inactive);

        final box = tester.widget<Container>(cover);
        expect(box.color, isNotNull);
        expect(box.color!.a, 1.0, reason: 'cover must be fully opaque');

        // Nothing from the calendar leaks into the cover subtree.
        expect(
          find.descendant(of: cover, matching: find.textContaining('period')),
          findsNothing,
        );
      },
    );
  });
}
