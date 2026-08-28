import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/main.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

/// A fresh in-memory database, closed automatically at the end of the test.
AppDatabase memoryDb() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Override [appDatabaseProvider] to hand out [db] already opened.
Override dbOverride(AppDatabase db) =>
    appDatabaseProvider.overrideWith((ref) async => db);

/// Resolve Future/Stream microtasks and short animations. **Not**
/// `pumpAndSettle` — the loading state animates a spinner forever.
Future<void> flush(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Pump [OlfApp] with [overrides], run [body], then tear the tree down **inside
/// the test body** and pump once more — that last step flushes drift's
/// stream-close timer before the binding's pending-timer check runs.
/// A surface tall enough that the whole calendar screen fits without scrolling,
/// so taps land without `ensureVisible` gymnastics.
Future<void> useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> pumpOlf(
  WidgetTester tester, {
  required List<Override> overrides,
  required Future<void> Function() body,
}) async {
  await useTallSurface(tester);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const OlfApp()),
  );
  await flush(tester);
  await body();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
