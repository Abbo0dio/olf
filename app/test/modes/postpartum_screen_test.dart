import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/modes/modes_providers.dart';
import 'package:olf_app/src/modes/postpartum_format.dart';
import 'package:olf_app/src/modes/postpartum_screen.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

void main() {
  final epoch = DateTime(2026);
  var nextId = 1;

  Period period(DateTime start) => Period(
    id: nextId++,
    startDate: start,
    endDate: start.add(const Duration(days: 3)),
    createdAt: epoch,
    updatedAt: epoch,
  );
  PregnancyEvent birth(DateTime d) =>
      PregnancyEvent(id: nextId++, kind: PregnancyEndKind.birth, date: d);

  setUp(() => nextId = 1);

  Future<void> pump(
    WidgetTester tester, {
    required List<PregnancyEvent> events,
    required List<Period> periods,
    required DateTime today,
  }) async {
    final r = derivePostpartumCycleReturn(
      events: events,
      periods: periods,
      today: today,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [postpartumCycleReturnProvider.overrideWithValue(r)],
        child: MaterialApp(
          theme: olfTheme(Brightness.light),
          home: const PostpartumScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('waiting state — no post-event period', (tester) async {
    await pump(
      tester,
      events: [birth(DateTime(2026, 4, 10))],
      periods: const [],
      today: DateTime(2026, 5, 20),
    );
    expect(
      find.textContaining("It's been 40 days since your birth"),
      findsOneWidget,
    );
    expect(find.textContaining('No period logged since then'), findsOneWidget);
    expect(find.text(postpartumDisclaimer), findsOneWidget);
    expect(find.textContaining('still settling'), findsOneWidget);
  });

  testWidgets('one cycle logged — no variability read yet', (tester) async {
    await pump(
      tester,
      events: [birth(DateTime(2026, 4, 10))],
      periods: [period(DateTime(2026, 7, 1))],
      today: DateTime(2026, 7, 10),
    );
    expect(find.textContaining('first period back was'), findsOneWidget);
    expect(find.textContaining('One cycle is not enough'), findsOneWidget);
  });

  testWidgets('settling read once >= 2 post-event cycles', (tester) async {
    await pump(
      tester,
      events: [birth(DateTime(2026, 3, 1))],
      periods: [
        period(DateTime(2026, 6, 1)),
        period(DateTime(2026, 7, 1)),
        period(DateTime(2026, 7, 29)),
      ],
      today: DateTime(2026, 8, 2),
    );
    expect(find.textContaining('look like they are settling'), findsOneWidget);
  });

  testWidgets('still-variable read for a wide spread', (tester) async {
    await pump(
      tester,
      events: [birth(DateTime(2026, 3, 1))],
      periods: [
        period(DateTime(2026, 6, 1)),
        period(DateTime(2026, 6, 27)),
        period(DateTime(2026, 8, 10)),
      ],
      today: DateTime(2026, 8, 20),
    );
    expect(find.textContaining('varying quite a bit'), findsOneWidget);
  });

  testWidgets('honest empty state when nothing is recorded', (tester) async {
    await pump(
      tester,
      events: const [],
      periods: const [],
      today: DateTime(2026, 8, 20),
    );
    expect(
      find.textContaining('Record a pregnancy loss or birth'),
      findsOneWidget,
    );
  });
}
