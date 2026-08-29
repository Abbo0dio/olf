import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();

  Finder chip(String label) => find.widgetWithText(FilterChip, label);

  /// Open the day sheet for today, then push the manage-symptoms screen.
  Future<void> openManage(WidgetTester tester) async {
    await tester.tap(
      find.bySemanticsLabel('${formatDay(today)}, no period logged'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage symptoms'));
    await tester.pumpAndSettle();
    expect(find.text('Manage symptoms'), findsOneWidget);
  }

  testWidgets('add a custom symptom → it appears in the day sheet', (
    tester,
  ) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openManage(tester);

        await tester.tap(find.text('Add symptom'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Cravings');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Cravings'), findsOneWidget);

        // back to the day sheet — the new symptom is a chip
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(chip('Cravings'), findsOneWidget);
      },
    );
  });

  testWidgets('rename a symptom', (tester) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openManage(tester);

        await tester.tap(find.byTooltip('Rename').first); // Cramps
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Belly cramps');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Belly cramps'), findsOneWidget);
        final names = (await repo.activeTypes()).map((t) => t.name);
        expect(names, contains('Belly cramps'));
        expect(names, isNot(contains('Cramps')));
      },
    );
  });

  testWidgets('remove a symptom → gone from the day sheet, entries kept', (
    tester,
  ) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);
    final acne = (await repo.activeTypes())
        .firstWhere((t) => t.name == 'Acne')
        .id;
    final seedDay = today.day > 1
        ? DateTime(today.year, today.month, 1)
        : DateTime(today.year, today.month, 2);
    await repo.setSymptom(seedDay, acne, present: true);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openManage(tester);

        // the Remove button sits on the same row as each name; Acne is 10th
        final acneRow = find.ancestor(
          of: find.text('Acne'),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(of: acneRow, matching: find.byTooltip('Remove')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Remove Acne?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Acne'), findsNothing);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(chip('Acne'), findsNothing);

        // the historical entry survived the archive
        expect(await repo.symptomsOn(seedDay), {acne});
      },
    );
  });

  testWidgets('reorder moves a symptom and the new order sticks', (
    tester,
  ) async {
    final db = memoryDb();
    final repo = DriftSymptomRepository(db);

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await openManage(tester);

        final before = (await repo.activeTypes()).map((t) => t.name).toList();

        // drag the first row's handle down past the second row
        await tester.drag(
          find.byIcon(Icons.drag_handle).first,
          const Offset(0, 120),
        );
        await tester.pumpAndSettle();

        final after = (await repo.activeTypes()).map((t) => t.name).toList();
        expect(after, isNot(before));
        expect(after.first, before[1]);
        expect(after.toSet(), before.toSet()); // same items, new order
      },
    );
  });
}
