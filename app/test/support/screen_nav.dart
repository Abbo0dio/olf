import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_app/src/prediction/accuracy_format.dart';
import 'package:olf_app/src/privacy/privacy_education_content.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

import 'harness.dart';

/// The canonical list of top-level UI surfaces, shared by the p5.1a a11y sweep
/// (`screen_guidelines_test.dart`, `semantics_labels_test.dart`) and the p5.1b
/// text-scaling sweep (`text_scaling_test.dart`) so the inventory never drifts.
///
/// Each [Surface] owns its own `pumpOlf` setup + navigation; a caller passes a
/// [SurfaceCheck] that runs against the mounted screen (inside `pumpOlf`'s
/// `body`, before its teardown).
///
/// 18 surfaces (p1.12 added the cycle-wheel active-phase one; p6.2 the
/// "Apps & export" / Apple Health connected one). The dispatch inventory named
/// `security/screen_security`, which is the non-visual `ScreenSecurity`
/// platform seam; `symptom_day_sheet` and `flow_quick_log` (the
/// flow/spotting/clot chip surface) stand in its place.
typedef SurfaceCheck = Future<void> Function(WidgetTester tester);

class Surface {
  Surface(this.name, this._run);

  final String name;
  final Future<void> Function(WidgetTester tester, SurfaceCheck check) _run;

  Future<void> run(WidgetTester tester, SurfaceCheck check) =>
      _run(tester, check);
}

List<Override> screenNavOverrides(AppDatabase db) => [
  dbOverride(db),
  // The forecast-sync provider only calls the scheduler for an enabled
  // reminder (none in these fixtures), but keep the platform channel out.
  reminderSchedulerProvider.overrideWithValue(_NoopScheduler()),
];

DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
}

Future<void> _seedHistory(AppDatabase db) async {
  final repo = DriftPeriodRepository(db);
  var d = DateTime(2025, 1, 5);
  for (final gap in const [28, 30, 27, 29, 28, 31, 27, 28, 30, 28]) {
    await repo.addPeriod(
      PeriodDraft(start: d, end: d.add(const Duration(days: 3))),
    );
    d = d.add(Duration(days: gap));
  }
}

/// Six periods, a regular 28 days apart, the most recent starting 20 days
/// ago — relative to `DateTime.now()` (unlike [_seedHistory]'s fixed dates)
/// so "today" always lands solidly inside a real, non-overdue cycle phase.
Future<void> _seedRecentCycle(AppDatabase db) async {
  final repo = DriftPeriodRepository(db);
  var start = _daysAgo(20 + 28 * 5);
  for (var i = 0; i < 6; i++) {
    await repo.addPeriod(
      PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
    );
    start = start.add(const Duration(days: 28));
  }
}

/// Put the app in the "Apple Health already connected" state so the
/// "Apps & export" section renders its full form (summary subtitle + "Sync
/// now"). A `FakeHealthPlatformGateway` override makes `healthAvailableProvider`
/// true; the stored keys stand in for a sync that already ran.
Future<void> _seedAppleHealthConnected(AppDatabase db) async {
  final settings = DriftSettingsRepository(db);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await settings.set(SettingKeys.appleHealthLastSync, '2,1,0');
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _openFromSettings(WidgetTester tester, Finder row) async {
  await _openSettings(tester);
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

String _todayCellLabel({required bool periodDay}) {
  final today = DateTime.now();
  return '${formatDay(today)}, ${periodDay ? 'period day' : 'no period logged'}';
}

final List<Surface> screenSurfaces = <Surface>[
  Surface('home_page — empty state', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () => check(tester),
    );
  }),

  Surface('period_calendar_page — with cycle history', (tester, check) async {
    final db = memoryDb();
    await _seedHistory(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        expect(find.text('History'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  // p1.12: `_seedHistory`'s fixed 2025 dates are stale by the time this runs,
  // so its cycle is always flagged a likely-missed-entry gap and the cycle
  // wheel above only ever renders its no-anchor placeholder there. This
  // surface seeds a regular, `_daysAgo`-relative history so "today" sits
  // inside a real phase, exercising the wheel's actual arcs/marker/labels
  // through the same guideline/label/contrast/keyboard-nav/text-scaling sweep.
  Surface('period_calendar_page — cycle wheel (active phase)', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedRecentCycle(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        expect(find.text('History'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('first_run_screen', (tester, check) async {
    await pumpOlf(
      tester,
      onboarded: false,
      overrides: screenNavOverrides(memoryDb()),
      body: () => check(tester),
    );
  }),

  Surface('pin_unlock_screen', (tester, check) async {
    await pumpOlf(
      tester,
      pinStore: FakePinStore(
        derivePinCredential('1379', iterations: 400, random: Random(1)),
      ),
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        expect(find.text('Enter your PIN'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('settings_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openSettings(tester);
        expect(find.text('Appearance'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('settings_page — Apps & export (Apple Health connected)', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedAppleHealthConnected(db);
    await pumpOlf(
      tester,
      overrides: [
        ...screenNavOverrides(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
      ],
      body: () async {
        await _openSettings(tester);
        await tester.scrollUntilVisible(
          find.text('Connect Apple Health'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await check(tester);
      },
    );
  }),

  Surface('meds_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await tester.tap(find.byTooltip('Medications'));
        await tester.pumpAndSettle();
        await check(tester);
      },
    );
  }),

  Surface('notifications_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(
          tester,
          find.widgetWithText(ListTile, 'Notifications'),
        );
        await check(tester);
      },
    );
  }),

  Surface('backup_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(tester, find.text('Backup & restore'));
        await check(tester);
      },
    );
  }),

  Surface('accuracy_page', (tester, check) async {
    final db = memoryDb();
    await _seedHistory(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openFromSettings(tester, find.text(accuracySettingsTitle));
        await flush(tester, 20);
        await check(tester);
      },
    );
  }),

  Surface('pregnancy_events_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(tester, find.text('Pregnancy loss & birth'));
        await check(tester);
      },
    );
  }),

  Surface('privacy_policy_screen', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(tester, find.text(privacyPolicyTitle));
        await check(tester);
      },
    );
  }),

  Surface('privacy_education_screen', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(tester, find.text(privacyEducationEntryLabel));
        await check(tester);
      },
    );
  }),

  Surface('privacy explainer detail screen', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await _openFromSettings(tester, find.text(privacyEducationEntryLabel));
        await tester.tap(find.text(privacyExplainers.first.title));
        await tester.pumpAndSettle();
        await check(tester);
      },
    );
  }),

  Surface('manage_symptoms_page', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(_todayCellLabel(periodDay: false)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage symptoms'));
        await tester.pumpAndSettle();
        await check(tester);
      },
    );
  }),

  Surface('symptom_day_sheet', (tester, check) async {
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(memoryDb()),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(_todayCellLabel(periodDay: false)),
        );
        await tester.pumpAndSettle();
        await check(tester);
      },
    );
  }),

  Surface('flow_quick_log sheet (flow / spotting / clot chips)', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await DriftPeriodRepository(
      db,
    ).addPeriod(PeriodDraft(start: _daysAgo(1), end: _daysAgo(0)));
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(_todayCellLabel(periodDay: true)),
        );
        await tester.pumpAndSettle();
        await check(tester);
      },
    );
  }),
];

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
