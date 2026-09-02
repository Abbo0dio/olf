import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_app/src/prediction/accuracy_format.dart';
import 'package:olf_app/src/privacy/privacy_education_content.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

import '../support/a11y.dart';
import '../support/harness.dart';

/// p5.1a — a screen reader must never land on an operable control with nothing
/// to announce. This walks the live semantics tree of each top-level screen and
/// fails if any node with a tap / long-press action has an empty
/// label + value + tooltip. Complements the `meetsGuideline` sweep in
/// `screen_guidelines_test.dart` (which only checks nodes Flutter tags as tap
/// targets); this catches bare `GestureDetector` / `InkWell` nodes too.
void main() {
  List<Override> overrides(AppDatabase db) => [
    dbOverride(db),
    reminderSchedulerProvider.overrideWithValue(_NoopScheduler()),
  ];

  final today = DateTime.now();
  DateTime daysAgo(int n) =>
      DateTime(today.year, today.month, today.day).subtract(Duration(days: n));

  Future<void> seedHistory(AppDatabase db) async {
    final repo = DriftPeriodRepository(db);
    var d = DateTime(2025, 1, 5);
    for (final gap in const [28, 30, 27, 29, 28, 31, 27, 28, 30, 28]) {
      await repo.addPeriod(
        PeriodDraft(start: d, end: d.add(const Duration(days: 3))),
      );
      d = d.add(Duration(days: gap));
    }
  }

  void expectAllTappablesLabelled(WidgetTester tester) {
    final offenders = unlabelledTappables(tester);
    expect(
      offenders,
      isEmpty,
      reason:
          'operable semantics nodes with no announcement:\n'
          '${offenders.join('\n')}',
    );
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> openFromSettings(WidgetTester tester, Finder row) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('home / calendar — every tappable is labelled', (tester) async {
    final db = memoryDb();
    await seedHistory(db);
    await pumpOlf(
      tester,
      overrides: overrides(db),
      body: () async {
        expect(find.text('History'), findsOneWidget);
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('first-run — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: overrides(memoryDb()),
      body: () async => expectAllTappablesLabelled(tester),
    );
  });

  testWidgets('PIN unlock — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      pinStore: FakePinStore(
        derivePinCredential('1379', iterations: 400, random: Random(1)),
      ),
      overrides: overrides(memoryDb()),
      body: () async {
        expect(find.text('Enter your PIN'), findsOneWidget);
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('settings — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openSettings(tester);
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('medications — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await tester.tap(find.byTooltip('Medications'));
        await tester.pumpAndSettle();
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('notifications — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(
          tester,
          find.widgetWithText(ListTile, 'Notifications'),
        );
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('backup & restore — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text('Backup & restore'));
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('accuracy — every tappable is labelled', (tester) async {
    final db = memoryDb();
    await seedHistory(db);
    await pumpOlf(
      tester,
      overrides: overrides(db),
      body: () async {
        await openFromSettings(tester, find.text(accuracySettingsTitle));
        await flush(tester, 20);
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('pregnancy events — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text('Pregnancy loss & birth'));
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('privacy policy — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyPolicyTitle));
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('privacy education — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyEducationEntryLabel));
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('privacy explainer detail — every tappable is labelled', (
    tester,
  ) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyEducationEntryLabel));
        await tester.tap(find.text(privacyExplainers.first.title));
        await tester.pumpAndSettle();
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('manage symptoms — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage symptoms'));
        await tester.pumpAndSettle();
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('symptom day sheet — every tappable is labelled', (tester) async {
    await pumpOlf(
      tester,
      overrides: overrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        expectAllTappablesLabelled(tester);
      },
    );
  });

  testWidgets('flow quick-log sheet — every tappable is labelled', (
    tester,
  ) async {
    final db = memoryDb();
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: daysAgo(1), end: daysAgo(0)));
    await pumpOlf(
      tester,
      overrides: overrides(db),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
        );
        await tester.pumpAndSettle();
        expectAllTappablesLabelled(tester);
      },
    );
  });
}

class _NoopScheduler implements ReminderScheduler {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> scheduleDaily(ReminderSchedule schedule) async {}
  @override
  Future<void> scheduleAt(ReminderKind kind, DateTime when) async {}
  @override
  Future<void> cancel(ReminderKind kind) async {}
}
