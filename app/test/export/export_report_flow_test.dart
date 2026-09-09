import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/backup/backup_providers.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';
import '../backup/fake_backup_gateway.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  Future<void> seed(AppDatabase db) async {
    final periods = DriftPeriodRepository(db);
    var start = daysAgo(20 + 28 * 5);
    for (var i = 0; i < 6; i++) {
      await periods.addPeriod(
        PeriodDraft(start: start, end: start.add(const Duration(days: 4))),
      );
      start = start.add(const Duration(days: 28));
    }
    final symptoms = DriftSymptomRepository(db);
    final cramps = (await symptoms.activeTypes()).first;
    for (var i = 0; i < 4; i++) {
      await symptoms.setSymptom(daysAgo(30 + i), cramps.id, present: true);
    }
    final bbt = DriftBbtRepository(db);
    for (var i = 0; i < 10; i++) {
      await bbt.setTemp(daysAgo(40 + i), 36.3 + (i % 4) * 0.1);
    }
  }

  Future<void> openScreen(WidgetTester tester) async {
    // r4: Settings → "Data & sharing" → Export report for a doctor.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data & sharing'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Export report for a doctor'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Export report for a doctor'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Export report for a doctor'),
      findsOneWidget,
    );
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw StateError('timed out waiting for $finder');
  }

  testWidgets('range picker, preview, and generate through the SAF seam', (
    tester,
  ) async {
    final db = memoryDb();
    final gateway = FakeBackupGateway();
    await seed(db);

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
      body: () async {
        await openScreen(tester);

        // Range picker — all four spans offered.
        for (final label in const [
          'Last 3 months',
          'Last 6 months',
          'Last 12 months',
          'All history',
        ]) {
          expect(find.text(label), findsOneWidget);
        }

        // Preview renders counts for the default (6-month) range.
        await pumpUntil(tester, find.textContaining('cycles'));
        expect(find.textContaining('Covers'), findsOneWidget);
        expect(find.textContaining('temperature readings'), findsOneWidget);

        // Switching the range rebuilds the preview.
        await tester.tap(find.text('Last 3 months'));
        await tester.pumpAndSettle();
        expect(find.textContaining('cycles'), findsWidgets);

        // Generate → the PDF goes through the file gateway.
        await tester.tap(find.text('Generate report'));
        await pumpUntil(tester, find.text('Report saved.'));

        expect(gateway.writeCount, 1);
        expect(gateway.lastDialogTitle, 'Save the report');
        expect(
          gateway.lastSuggestedName,
          matches(RegExp(r'^olf-report-\d{4}-\d{2}-\d{2}\.pdf$')),
        );
        final bytes = gateway.file!;
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(3000));
      },
    );
  });

  testWidgets('generate is disabled until there is something to export', (
    tester,
  ) async {
    final db = memoryDb();
    final gateway = FakeBackupGateway();

    await pumpOlf(
      tester,
      overrides: [
        dbOverride(db),
        backupFileGatewayProvider.overrideWithValue(gateway),
      ],
      body: () async {
        await openScreen(tester);
        await pumpUntil(tester, find.textContaining('Nothing logged'));
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Generate report'),
            matching: find.bySubtype<FilledButton>(),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );
  });
}
