import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_editor.dart';
import 'package:olf_app/src/providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

/// Mounts a bare screen whose button opens the period editor, so the sheet can
/// be tested without the calendar around it. Uses real providers over an
/// in-memory database.
class _Host extends ConsumerWidget {
  const _Host({this.initialStart, required this.onClosed});

  final DateTime? initialStart;
  final void Function(PeriodEditorOutcome?) onClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate on the database opening, exactly as the real screen does — the
    // editor reads period providers that require the DB to be ready.
    final ready = ref.watch(appDatabaseProvider).hasValue;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ready
              ? Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      final outcome = await showPeriodEditor(
                        context,
                        initialStart: initialStart,
                      );
                      onClosed(outcome);
                    },
                    child: const Text('open'),
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

Future<AppDatabase> _seededDb(List<PeriodDraft> drafts) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = DriftPeriodRepository(db);
  for (final d in drafts) {
    await repo.addPeriod(d);
  }
  return db;
}

void main() {
  final lastYearJan10 = DateTime(DateTime.now().year - 1, 1, 10);
  final lastYearJan15 = DateTime(DateTime.now().year - 1, 1, 15);

  /// Pump the host, open the editor, run [body], then tear the tree down inside
  /// the test so drift's stream-close timer is flushed before the invariant
  /// check.
  Future<void> withEditor(
    WidgetTester tester, {
    required AppDatabase db,
    DateTime? initialStart,
    required Future<void> Function(ValueGetter<PeriodEditorOutcome?> outcome)
    body,
  }) async {
    await useTallSurface(tester);
    PeriodEditorOutcome? outcome;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
        child: _Host(initialStart: initialStart, onClosed: (o) => outcome = o),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await body(() => outcome);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('opens with the seeded start date and both date fields', (
    tester,
  ) async {
    final db = await _seededDb(const []);
    await withEditor(
      tester,
      db: db,
      initialStart: lastYearJan10,
      body: (outcome) async {
        expect(find.text('Log a period'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('This period has ended'), findsOneWidget);

        expect(find.text('End'), findsNothing);
        await tester.tap(find.text('This period has ended'));
        await tester.pumpAndSettle();
        expect(find.text('End'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(outcome(), isNull);
      },
    );
  });

  testWidgets('a valid draft saves and reports "saved"', (tester) async {
    final db = await _seededDb(const []);
    await withEditor(
      tester,
      db: db,
      initialStart: lastYearJan10,
      body: (outcome) async {
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(outcome(), PeriodEditorOutcome.saved);
        expect(await DriftPeriodRepository(db).allPeriods(), hasLength(1));
      },
    );
  });

  testWidgets('an overlapping start is blocked with a clear message', (
    tester,
  ) async {
    final db = await _seededDb([
      PeriodDraft(start: lastYearJan10, end: lastYearJan15),
    ]);
    await withEditor(
      tester,
      db: db,
      initialStart: DateTime(DateTime.now().year - 1, 1, 12),
      body: (outcome) async {
        expect(
          find.text('This overlaps a period you have already logged.'),
          findsOneWidget,
        );
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(save.onPressed, isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(outcome(), isNull);
        expect(await DriftPeriodRepository(db).allPeriods(), hasLength(1));
      },
    );
  });
}
