import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  final today = DateTime.now();

  testWidgets(
    'enter a basal temperature in °F from the day sheet → stored as °C, '
    'shown back in °F',
    (tester) async {
      final db = memoryDb();
      final bbt = DriftBbtRepository(db);

      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          await tester.tap(
            find.bySemanticsLabel('${formatDay(today)}, no period logged'),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Add basal temperature'));
          await tester.pumpAndSettle();
          expect(
            find.text('Basal temperature — ${formatDay(today)}'),
            findsOneWidget,
          );

          // switch the dialog to Fahrenheit and type a reading
          await tester.tap(find.text('°F'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '97.7');
          await tester.pump();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          // stored canonically in Celsius
          final row = await bbt.tempOn(today);
          expect(row, isNotNull);
          expect(row!.tempCelsius, closeTo(fahrenheitToCelsius(97.7), 1e-6));

          // the chip reflects it back in the chosen unit
          expect(find.textContaining('Basal temp: 97.7 °F'), findsOneWidget);
        },
      );
    },
  );

  testWidgets('an implausible reading is blocked with a message', (
    tester,
  ) async {
    final db = memoryDb();

    await pumpOlf(
      tester,
      overrides: [dbOverride(db)],
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add basal temperature'));
        await tester.pumpAndSettle();

        // 80 °C is nonsense for a basal temperature
        await tester.enterText(find.byType(TextField), '80');
        await tester.pump();

        expect(find.text(BbtError.tooHigh.describe()), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
              .onPressed,
          isNull, // Save disabled
        );
      },
    );
  });
}
