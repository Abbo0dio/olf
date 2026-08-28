import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/main.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

AppDatabase _memoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Resolve FutureProvider / StreamProvider microtasks and any SnackBar
/// animation. Not `pumpAndSettle` — the loading state animates a
/// `CircularProgressIndicator` forever.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Pumps the app, runs [body] against it, then tears the tree down **inside the
/// test body** and pumps once more. That last step flushes drift's stream-query
/// close timer (a `Timer.zero` scheduled when Riverpod disposes the stream
/// subscription) before the binding's pending-timer check runs.
Future<void> _runHome(
  WidgetTester tester, {
  required List<Override> overrides,
  required Future<void> Function() body,
}) async {
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const OlfApp()),
  );
  await _flush(tester);
  await body();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Override _db(AppDatabase database) =>
    appDatabaseProvider.overrideWith((ref) async => database);

void main() {
  testWidgets('empty state shows the app name and the log button', (
    tester,
  ) async {
    await _runHome(
      tester,
      overrides: [_db(_memoryDb())],
      body: () async {
        expect(find.widgetWithText(AppBar, 'olf'), findsOneWidget);
        expect(find.text('Nothing logged yet.'), findsOneWidget);
        expect(find.text('Period started today'), findsOneWidget);
      },
    );
  });

  testWidgets('renders in dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await _runHome(
      tester,
      overrides: [_db(_memoryDb())],
      body: () async {
        final context = tester.element(find.text('Nothing logged yet.'));
        expect(Theme.of(context).brightness, Brightness.dark);
      },
    );
  });

  testWidgets('tapping the button logs today and shows "Day 1"', (
    tester,
  ) async {
    await _runHome(
      tester,
      overrides: [_db(_memoryDb())],
      body: () async {
        await tester.tap(find.text('Period started today'));
        await _flush(tester);

        expect(find.text('Day 1'), findsOneWidget);
        expect(find.text('Period started today'), findsNothing);
        expect(find.text('Remove this entry'), findsOneWidget);
      },
    );
  });

  testWidgets('a pre-existing period start shows the right "Day N"', (
    tester,
  ) async {
    final db = _memoryDb();
    const startedDaysAgo = 4;
    await DriftCycleEventRepository(db).logPeriodStart(
      DateTime.now().subtract(const Duration(days: startedDaysAgo)),
    );

    await _runHome(
      tester,
      overrides: [_db(db)],
      body: () async {
        expect(find.text('Day ${startedDaysAgo + 1}'), findsOneWidget);
      },
    );
  });

  testWidgets('remove takes you back to the empty state', (tester) async {
    final db = _memoryDb();
    await DriftCycleEventRepository(db).logPeriodStart(DateTime.now());

    await _runHome(
      tester,
      overrides: [_db(db)],
      body: () async {
        expect(find.text('Day 1'), findsOneWidget);

        await tester.tap(find.text('Remove this entry'));
        await _flush(tester);

        expect(find.text('Nothing logged yet.'), findsOneWidget);
      },
    );
  });

  testWidgets('missing key → fail-safe screen, no log button', (tester) async {
    await _runHome(
      tester,
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) async => throw const MissingDatabaseKeyException(),
        ),
      ],
      body: () async {
        expect(find.text("Can't unlock your data"), findsOneWidget);
        expect(find.text('Period started today'), findsNothing);
      },
    );
  });
}
