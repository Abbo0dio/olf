import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/a11y/spoken_detail.dart';
import 'package:olf_app/src/modes/pregnancy_mode_format.dart';
import 'package:olf_app/src/modes/pregnancy_mode_providers.dart';
import 'package:olf_app/src/modes/pregnancy_week_screen.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

import '../support/harness.dart';

void main() {
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PregnancyStartReference? reference,
    required GestationalAge? ga,
    bool reduceSpoken = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pregnancyStartReferenceProvider.overrideWith(
            (ref) => Stream.value(reference),
          ),
          gestationalAgeProvider.overrideWithValue(ga),
          reduceSpokenDetailProvider.overrideWith(
            (ref) => Stream.value(reduceSpoken),
          ),
        ],
        child: MaterialApp(
          theme: olfTheme(Brightness.light),
          home: const PregnancyWeekScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no start reference → the set-your-start-date state', (
    tester,
  ) async {
    await pumpScreen(tester, reference: null, ga: null);
    expect(find.text('Set your start date'), findsOneWidget);
    expect(find.text('Add start date'), findsOneWidget);
    expect(find.text(pregnancyModeDisclaimer), findsOneWidget);
  });

  testWidgets('a future reference → the check-your-dates state, no week', (
    tester,
  ) async {
    final reference = PregnancyStartReference(
      kind: PregnancyReferenceKind.dueDate,
      date: daysAgo(-30), // 30 days from now
    );
    await pumpScreen(tester, reference: reference, ga: null);
    expect(find.text('Check your dates'), findsOneWidget);
    expect(find.textContaining('Week '), findsNothing);
    expect(find.text(pregnancyModeDisclaimer), findsOneWidget);
  });

  testWidgets(
    'populated week view renders the right week, trimester and note',
    (tester) async {
      final reference = PregnancyStartReference(
        kind: PregnancyReferenceKind.lastMenstrualPeriod,
        date: daysAgo(24 * 7 + 3),
      );
      const ga = GestationalAge(completedWeeks: 24, daysIntoWeek: 3);
      await pumpScreen(tester, reference: reference, ga: ga);

      expect(find.text('Week 24, 3 days'), findsOneWidget);
      expect(find.textContaining('Second trimester'), findsOneWidget);
      expect(find.text(pregnancyWeekNote(24)), findsOneWidget);
      expect(find.textContaining('Estimated due date around'), findsOneWidget);
      expect(find.text('Change start date'), findsOneWidget);
      expect(find.text(pregnancyModeDisclaimer), findsOneWidget);
    },
  );

  testWidgets('reduce-spoken-detail redacts the week headline only', (
    tester,
  ) async {
    final reference = PregnancyStartReference(
      kind: PregnancyReferenceKind.lastMenstrualPeriod,
      date: daysAgo(80),
    );
    const ga = GestationalAge(completedWeeks: 11, daysIntoWeek: 3);
    await pumpScreen(tester, reference: reference, ga: ga, reduceSpoken: true);

    final headline = tester.widget<Text>(find.text('Week 11, 3 days'));
    expect(headline.semanticsLabel, gestationalAgeHeadlineRedacted);
    // The visible note text is untouched by the redaction.
    expect(find.text(pregnancyWeekNote(11)), findsOneWidget);
  });

  testWidgets(
    'enable pregnancy mode, set a start reference, week view appears; '
    'toggling off keeps the reference',
    (tester) async {
      final db = memoryDb();
      await pumpOlf(
        tester,
        overrides: [dbOverride(db)],
        body: () async {
          // Into Settings → Modes.
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Life-stage & condition modes'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Life-stage & condition modes'));
          await tester.pumpAndSettle();

          // Turn pregnancy mode on.
          await tester.tap(find.widgetWithText(SwitchListTile, 'Pregnancy'));
          await tester.pumpAndSettle();
          expect(
            lifeStageModeEnabled(
              await DriftSettingsRepository(db).get('mode.pregnancy'),
            ),
            isTrue,
          );

          // Open the screen — it starts in the needs-a-date state.
          await tester.scrollUntilVisible(
            find.text('Open Pregnancy'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Open Pregnancy'));
          await tester.pumpAndSettle();
          expect(find.text('Add start date'), findsOneWidget);

          // Add a start date via the sheet: last period, 10 weeks back.
          await tester.tap(find.text('Add start date'));
          await tester.pumpAndSettle();
          expect(find.text('First day of last period'), findsOneWidget);
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();

          // A week is now shown (default sheet date = today → week 0).
          expect(find.textContaining('Week '), findsOneWidget);
          final stored = decodePregnancyStartReference(
            await DriftSettingsRepository(db).get(pregnancyStartReferenceKey),
          );
          expect(stored, isNotNull);
          expect(stored!.kind, PregnancyReferenceKind.lastMenstrualPeriod);

          // Back out, turn the mode off, and confirm the reference survives.
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(SwitchListTile, 'Pregnancy'));
          await tester.pumpAndSettle();
          expect(
            lifeStageModeEnabled(
              await DriftSettingsRepository(db).get('mode.pregnancy'),
            ),
            isFalse,
          );
          expect(
            await DriftSettingsRepository(db).get(pregnancyStartReferenceKey),
            isNotNull,
          );
        },
      );
    },
  );
}
