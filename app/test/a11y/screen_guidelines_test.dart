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

/// p5.1a — the automated accessibility-guideline harness run over every
/// top-level screen. Each test pumps a screen in a realistic state and asserts
/// [labeledTapTargetGuideline] (every operable control announces something) and
/// the Android + iOS minimum-tap-target-size guidelines — the audit found the
/// existing UI already meets all three, so they are locked in here rather than
/// deferred.
///
/// The one deferral is `contrast: false` → **p5.1c**, which owns the systematic
/// WCAG contrast sweep across *both* themes (a pure test over the theme tokens);
/// `textContrastGuideline` here would only check the one brightness a given test
/// happens to pump. Text-scaling reflow is **p5.1b**. No screen is skipped.
///
/// Screen inventory note: the dispatch listed `security/screen_security`, which
/// is a non-visual platform seam (`ScreenSecurity`), not a screen — there is no
/// UI to audit. The interactive `symptom_day_sheet` and `flow_quick_log`
/// surfaces are audited instead, so the sweep still covers 16 real surfaces.
/// Flagged in the PR.
void main() {
  List<Override> baseOverrides(AppDatabase db) => [
    dbOverride(db),
    // Belt-and-braces: the forecast-sync provider only calls the scheduler
    // for an *enabled* reminder (none here), but keep the platform channel
    // out of the a11y run entirely.
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

  testWidgets('home_page — empty state', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('period_calendar_page — with cycle history', (tester) async {
    final db = memoryDb();
    await seedHistory(db);
    await pumpOlf(
      tester,
      overrides: baseOverrides(db),
      body: () async {
        expect(find.text('History'), findsOneWidget);
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('first_run_screen', (tester) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('pin_unlock_screen', (tester) async {
    await pumpOlf(
      tester,
      pinStore: FakePinStore(
        derivePinCredential('1379', iterations: 400, random: Random(1)),
      ),
      overrides: baseOverrides(memoryDb()),
      body: () async {
        expect(find.text('Enter your PIN'), findsOneWidget);
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('settings_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openSettings(tester);
        expect(find.text('Appearance'), findsOneWidget);
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('meds_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await tester.tap(find.byTooltip('Medications'));
        await tester.pumpAndSettle();
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('notifications_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(
          tester,
          find.widgetWithText(ListTile, 'Notifications'),
        );
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('backup_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text('Backup & restore'));
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('accuracy_page', (tester) async {
    final db = memoryDb();
    await seedHistory(db);
    await pumpOlf(
      tester,
      overrides: baseOverrides(db),
      body: () async {
        await openFromSettings(tester, find.text(accuracySettingsTitle));
        await flush(tester, 20);
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('pregnancy_events_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text('Pregnancy loss & birth'));
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('privacy_policy_screen', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyPolicyTitle));
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('privacy_education_screen', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyEducationEntryLabel));
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('privacy explainer detail screen', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await openFromSettings(tester, find.text(privacyEducationEntryLabel));
        await tester.tap(find.text(privacyExplainers.first.title));
        await tester.pumpAndSettle();
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('manage_symptoms_page', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage symptoms'));
        await tester.pumpAndSettle();
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('symptom_day_sheet', (tester) async {
    await pumpOlf(
      tester,
      overrides: baseOverrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, no period logged'),
        );
        await tester.pumpAndSettle();
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
      },
    );
  });

  testWidgets('flow_quick_log sheet (flow / spotting / clot chips)', (
    tester,
  ) async {
    final db = memoryDb();
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: daysAgo(1), end: daysAgo(0)));
    await pumpOlf(
      tester,
      overrides: baseOverrides(db),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel('${formatDay(today)}, period day'),
        );
        await tester.pumpAndSettle();
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        await expectMeetsA11yGuidelines(tester, contrast: false);
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
