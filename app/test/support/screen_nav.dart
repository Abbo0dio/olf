import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/health/health_providers.dart';
import 'package:olf_app/src/modes/pregnancy_mode_providers.dart';
import 'package:olf_app/src/period/period_format.dart';
import 'package:olf_app/src/prediction/accuracy_format.dart';
import 'package:olf_app/src/privacy/privacy_education_content.dart';
import 'package:olf_app/src/privacy/privacy_policy_content.dart';
import 'package:olf_app/src/reminders/reminder_providers.dart';
import 'package:olf_app/src/reminders/reminder_scheduler.dart';
import 'package:olf_core/olf_core.dart';

import '../health/conflict_fixtures.dart';
import 'harness.dart';

/// The canonical list of top-level UI surfaces, shared by the p5.1a a11y sweep
/// (`screen_guidelines_test.dart`, `semantics_labels_test.dart`) and the p5.1b
/// text-scaling sweep (`text_scaling_test.dart`) so the inventory never drifts.
///
/// Each [Surface] owns its own `pumpOlf` setup + navigation; a caller passes a
/// [SurfaceCheck] that runs against the mounted screen (inside `pumpOlf`'s
/// `body`, before its teardown).
///
/// 40 surfaces (p1.12 added the cycle-wheel active-phase one; p6.2 the
/// "Apps & export" / health-app-connected one — still shared and unchanged in
/// p6.3, the tile is platform-neutral; p6.4 the conflict-review screen; p6.5 the
/// doctor-report export screen; p7.1 the Modes page, the postpartum
/// cycle-return screen and the loss/birth support-resources screen; p7.2a the
/// pregnancy week view in its needs-a-start-date and populated states; p7.2b the
/// pregnancy symptom-logging screen; p7.3 the TTC fertility-score screen and its
/// not-enough-history state; p7.4 the PCOS screen in its correlation-view and
/// not-enough-data states; p7.8 the birth-control recalibration explainer; p7.7
/// the perimenopause screen in its transition-read + symptom-timeline and its
/// thin-history states; p7.5 the endometriosis screen in its correlation-view
/// and empty states and the pain-logging sheet; p7.6 the PMDD screen in its
/// overlay-view and empty states and the daily rating sheet).
/// The dispatch inventory named
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

/// Put the app in the "health app already connected" state so the
/// "Apps & export" section renders its full form (summary subtitle + "Sync
/// now"). A `FakeHealthPlatformGateway` override makes `healthAvailableProvider`
/// true; the stored keys stand in for a sync that already ran.
Future<void> _seedHealthAppConnected(AppDatabase db) async {
  final settings = DriftSettingsRepository(db);
  await settings.set(SettingKeys.appleHealthConnected, 'true');
  await settings.set(SettingKeys.appleHealthLastSync, '2,1,0');
  // p8.1a: two passive Apple Watch wrist-temperature readings so the per-source
  // status line under the health tile renders.
  final bbt = DriftBbtRepository(db);
  for (final ago in const [1, 2]) {
    await bbt.setTemp(
      _daysAgo(ago),
      36.8,
      source: HealthDataSource.appleHealth,
      externalId: 'hk-wrist-$ago',
      measurementKind: BbtMeasurementKind.sleepingWrist,
    );
  }
}

/// Seed postpartum mode on, a recorded birth, and three post-event periods so
/// the postpartum cycle-return screen renders its fullest ("settling") state.
Future<void> _seedPostpartumMode(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.postpartum.settingKey, 'true');
  await DriftCycleEventRepository(
    db,
  ).logPregnancyEnd(PregnancyEndKind.birth, _daysAgo(150));
  final repo = DriftPeriodRepository(db);
  for (final ago in const [90, 62, 34]) {
    await repo.addPeriod(
      PeriodDraft(start: _daysAgo(ago), end: _daysAgo(ago - 3)),
    );
  }
}

/// Same, but a loss — used to reach the loss variant of the resources screen.
Future<void> _seedPostpartumAfterLoss(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.postpartum.settingKey, 'true');
  await DriftCycleEventRepository(
    db,
  ).logPregnancyEnd(PregnancyEndKind.loss, _daysAgo(40));
}

/// Pregnancy mode on, with a last-period start reference ~24 weeks back so the
/// week view renders its populated state (week 24, day 3 — second trimester).
Future<void> _seedPregnancyMode(AppDatabase db) async {
  final settings = DriftSettingsRepository(db);
  await settings.set(LifeStageMode.pregnancy.settingKey, 'true');
  await settings.set(
    pregnancyStartReferenceKey,
    encodePregnancyStartReference(
      PregnancyStartReference(
        kind: PregnancyReferenceKind.lastMenstrualPeriod,
        date: _daysAgo(24 * 7 + 3),
      ),
    ),
  );
}

/// Pregnancy mode on but no start reference entered — the week view's
/// "set your start date" state.
Future<void> _seedPregnancyModeNoReference(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.pregnancy.settingKey, 'true');
}

/// TTC mode on with a regular history whose most recent period started 10 days
/// ago, so today's outlook sits in the run-up to the estimated fertile window
/// and the score screen renders its fullest state.
Future<void> _seedTtcMode(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.ttc.settingKey, 'true');
  final repo = DriftPeriodRepository(db);
  var start = _daysAgo(10 + 28 * 7);
  for (var i = 0; i < 8; i++) {
    await repo.addPeriod(
      PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
    );
    start = start.add(const Duration(days: 28));
  }
}

/// TTC mode on with only one logged period — not enough history, so the score
/// screen shows its "keep logging" empty state.
Future<void> _seedTtcModeThinHistory(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.ttc.settingKey, 'true');
  await DriftPeriodRepository(
    db,
  ).addPeriod(PeriodDraft(start: _daysAgo(12), end: _daysAgo(9)));
}

/// Birth-control-change mode on — enough to reach its guided recalibration
/// explainer from Settings → Modes (p7.8).
Future<void> _seedBirthControlSwitchMode(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.birthControlSwitch.settingKey, 'true');
}

/// PCOS mode on, four periods 28 days apart (three completed cycles + the open
/// one) and a "Cramps" symptom logged on luteal-phase days across them, so the
/// correlation view renders its fullest state (a chart + a named phase).
Future<void> _seedPcosModeWithCorrelation(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.pcos.settingKey, 'true');
  final periods = DriftPeriodRepository(db);
  for (final ago in const [112, 84, 56, 28]) {
    await periods.addPeriod(
      PeriodDraft(start: _daysAgo(ago), end: _daysAgo(ago - 3)),
    );
  }
  final symptoms = DriftSymptomRepository(db);
  final cramps = (await symptoms.activeTypes()).firstWhere(
    (t) => t.name == 'Cramps',
  );
  for (final ago in const [90, 88, 86, 62, 60, 58, 34, 32, 30]) {
    await symptoms.setSymptom(_daysAgo(ago), cramps.id, present: true);
  }
}

/// PCOS mode on with a single logged symptom and no cycle history — the
/// correlation tile's "not enough data yet" state.
Future<void> _seedPcosModeNotEnoughData(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.pcos.settingKey, 'true');
  final symptoms = DriftSymptomRepository(db);
  final cramps = (await symptoms.activeTypes()).firstWhere(
    (t) => t.name == 'Cramps',
  );
  await symptoms.setSymptom(_daysAgo(2), cramps.id, present: true);
}

/// Perimenopause mode on, a history whose cycle-length spread widens over time
/// (no missed-entry gap), and a perimenopause-relevant built-in symptom
/// ("Low mood") logged on luteal-phase days across the recent cycles — so the
/// mode screen renders its fullest state: a "becoming less regular" transition
/// read plus a symptom timeline with a chart.
Future<void> _seedPerimenopauseMode(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.perimenopause.settingKey, 'true');
  final periods = DriftPeriodRepository(db);
  // Oldest → newest, most recent 8 days ago. Earlier gaps tight (27–29),
  // later gaps wide (24–41) — spread widens, nothing over 45 days.
  var start = _daysAgo(8 + 28 + 27 + 29 + 28 + 41 + 24 + 39);
  for (final gap in const [28, 27, 29, 28, 41, 24, 39]) {
    await periods.addPeriod(
      PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
    );
    start = start.add(Duration(days: gap));
  }
  await periods.addPeriod(
    PeriodDraft(start: start, end: start.add(const Duration(days: 3))),
  );
  final symptoms = DriftSymptomRepository(db);
  final lowMood = (await symptoms.activeTypes()).firstWhere(
    (t) => t.name == 'Low mood',
  );
  for (var ago = 12; ago <= 120; ago += 12) {
    await symptoms.setSymptom(_daysAgo(ago), lowMood.id, present: true);
  }
}

/// Perimenopause mode on with a single logged period — not enough history, so
/// the transition read is the "keep logging" state and the timeline is empty.
Future<void> _seedPerimenopauseModeThinHistory(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.perimenopause.settingKey, 'true');
  await DriftPeriodRepository(
    db,
  ).addPeriod(PeriodDraft(start: _daysAgo(12), end: _daysAgo(9)));
}

/// Endometriosis mode on, four periods 28 days apart (three completed cycles +
/// the open one) and pain / flare days logged in the luteal phase across them,
/// so the correlation view renders its fullest state (a chart + a named phase).
Future<void> _seedEndometriosisModeWithFlares(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.endometriosis.settingKey, 'true');
  final periods = DriftPeriodRepository(db);
  for (final ago in const [112, 84, 56, 28]) {
    await periods.addPeriod(
      PeriodDraft(start: _daysAgo(ago), end: _daysAgo(ago - 3)),
    );
  }
  final pain = DriftPainRepository(db);
  for (final ago in const [95, 93, 91, 67, 65, 63, 39, 37, 35]) {
    await pain.setPain(
      _daysAgo(ago),
      intensity: SymptomSeverity.moderate,
      region: PainRegion.pelvic,
      isFlare: true,
    );
  }
}

/// Endometriosis mode on with nothing logged — the screen's empty state.
Future<void> _seedEndometriosisModeEmpty(AppDatabase db) async {
  await DriftSettingsRepository(
    db,
  ).set(LifeStageMode.endometriosis.settingKey, 'true');
}

/// PMDD mode on, four periods 28 days apart (three completed cycles + the open
/// one) and higher-rated days in the luteal phase across them, so the overlay
/// renders its fullest state (a chart + the "runs higher in luteal" read).
Future<void> _seedPmddModeWithRatings(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.pmdd.settingKey, 'true');
  final periods = DriftPeriodRepository(db);
  for (final ago in const [112, 84, 56, 28]) {
    await periods.addPeriod(
      PeriodDraft(start: _daysAgo(ago), end: _daysAgo(ago - 3)),
    );
  }
  final pmdd = DriftPmddRatingRepository(db);
  // Luteal days (~d17..d28) of each completed cycle, plus one milder day.
  for (final ago in const [95, 93, 91, 67, 65, 63, 39, 37, 35]) {
    await pmdd.rateDay(_daysAgo(ago), const {
      PmddSymptom.irritability: SymptomSeverity.severe,
      PmddSymptom.lowMood: SymptomSeverity.moderate,
      PmddSymptom.bloating: SymptomSeverity.none,
    });
  }
  for (final ago in const [104, 76, 48]) {
    await pmdd.rateDay(_daysAgo(ago), const {
      PmddSymptom.fatigue: SymptomSeverity.mild,
    });
  }
}

/// PMDD mode on with nothing rated — the screen's empty state.
Future<void> _seedPmddModeEmpty(AppDatabase db) async {
  await DriftSettingsRepository(db).set(LifeStageMode.pmdd.settingKey, 'true');
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _openModesPage(WidgetTester tester) async {
  await _openFromSettings(tester, find.text('Life-stage & condition modes'));
}

Future<void> _openPostpartumScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Postpartum');
}

Future<void> _openPregnancyScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Pregnancy');
}

Future<void> _openTtcScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Trying to conceive');
}

Future<void> _openPcosScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open PCOS');
}

Future<void> _openPerimenopauseScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Perimenopause');
}

Future<void> _openEndometriosisScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Endometriosis');
}

Future<void> _openPmddScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open PMDD');
}

Future<void> _openPregnancySymptomsScreen(WidgetTester tester) async {
  await _openPregnancyScreen(tester);
  final row = find.text('Log pregnancy symptoms');
  await tester.scrollUntilVisible(
    row,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _openBirthControlSwitchScreen(WidgetTester tester) async {
  await _openModeScreen(tester, 'Open Birth-control change');
}

Future<void> _openModeScreen(WidgetTester tester, String rowLabel) async {
  await _openModesPage(tester);
  final row = find.text(rowLabel);
  await tester.scrollUntilVisible(
    row,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
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

  Surface('settings_page — Apps & export (health app connected)', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedHealthAppConnected(db);
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
          find.text('Connect a health app'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await check(tester);
      },
    );
  }),

  Surface('conflict_review_screen — differences to review', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    final settings = DriftSettingsRepository(db);
    await settings.set(SettingKeys.appleHealthConnected, 'true');
    await DriftBbtRepository(db).setTemp(DateTime(2026, 5, 10), 36.4);
    await pumpOlf(
      tester,
      overrides: [
        ...screenNavOverrides(db),
        healthPlatformGatewayProvider.overrideWithValue(
          FakeHealthPlatformGateway(),
        ),
        healthConflictsProvider.overrideWith(
          seededConflicts([
            bbtConflict(DateTime(2026, 5, 10), local: 36.4, incoming: 36.9),
            flowConflict(
              DateTime(2026, 5, 11),
              local: FlowIntensity.spotting,
              incoming: FlowIntensity.heavy,
            ),
          ]),
        ),
      ],
      body: () async {
        await _openSettings(tester);
        await tester.scrollUntilVisible(
          find.textContaining('to review'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.textContaining('to review'));
        await tester.pumpAndSettle();
        expect(find.text('Keep mine'), findsWidgets);
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

  Surface('export_report_screen', (tester, check) async {
    final db = memoryDb();
    await _seedHistory(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openFromSettings(
          tester,
          find.text('Export report for a doctor'),
        );
        expect(find.text('Generate report'), findsOneWidget);
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

  Surface('modes_page — Phase 7 mode list', (tester, check) async {
    final db = memoryDb();
    await _seedPostpartumMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openModesPage(tester);
        expect(find.widgetWithText(AppBar, 'Modes'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('postpartum_screen — cycle-return view', (tester, check) async {
    final db = memoryDb();
    await _seedPostpartumMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPostpartumScreen(tester);
        expect(find.widgetWithText(AppBar, 'Postpartum'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('support_resources_screen — after a loss', (tester, check) async {
    final db = memoryDb();
    await _seedPostpartumAfterLoss(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPostpartumScreen(tester);
        await tester.tap(find.text('Support & resources'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'After a loss'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pregnancy_week_screen — set your start date', (tester, check) async {
    final db = memoryDb();
    await _seedPregnancyModeNoReference(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPregnancyScreen(tester);
        expect(find.widgetWithText(AppBar, 'Pregnancy'), findsOneWidget);
        expect(find.text('Add start date'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pregnancy_week_screen — week view', (tester, check) async {
    final db = memoryDb();
    await _seedPregnancyMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPregnancyScreen(tester);
        expect(find.textContaining('Week 24'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pregnancy_symptoms_screen — log through the symptom repo', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedPregnancyMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPregnancySymptomsScreen(tester);
        expect(
          find.widgetWithText(AppBar, 'Pregnancy symptoms'),
          findsOneWidget,
        );
        await check(tester);
      },
    );
  }),

  Surface('ttc_screen — daily fertility score', (tester, check) async {
    final db = memoryDb();
    await _seedTtcMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openTtcScreen(tester);
        expect(
          find.widgetWithText(AppBar, 'Trying to conceive'),
          findsOneWidget,
        );
        expect(find.textContaining('Fertile window:'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('ttc_screen — not enough history', (tester, check) async {
    final db = memoryDb();
    await _seedTtcModeThinHistory(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openTtcScreen(tester);
        expect(find.text('Not enough history yet'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pcos_screen — symptom-vs-cycle-phase correlation view', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedPcosModeWithCorrelation(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPcosScreen(tester);
        expect(find.widgetWithText(AppBar, 'PCOS'), findsOneWidget);
        expect(find.text('Cramps'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pcos_screen — not enough data yet', (tester, check) async {
    final db = memoryDb();
    await _seedPcosModeNotEnoughData(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPcosScreen(tester);
        expect(find.widgetWithText(AppBar, 'PCOS'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('perimenopause_screen — transition read + symptom timeline', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedPerimenopauseMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPerimenopauseScreen(tester);
        expect(find.widgetWithText(AppBar, 'Perimenopause'), findsOneWidget);
        expect(find.text('Low mood'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('perimenopause_screen — thin history', (tester, check) async {
    final db = memoryDb();
    await _seedPerimenopauseModeThinHistory(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPerimenopauseScreen(tester);
        expect(find.widgetWithText(AppBar, 'Perimenopause'), findsOneWidget);
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

  // p8.1a: the day sheet with a passively-captured Apple Watch reading for
  // today — the temperature chip carries the "captured while you slept"
  // sub-label, and tapping it corrects the value into a typed basal reading.
  Surface('symptom_day_sheet — passive Apple Watch temperature', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await DriftBbtRepository(db).setTemp(
      _daysAgo(0),
      36.9,
      source: HealthDataSource.appleHealth,
      externalId: 'hk-wrist-today',
      measurementKind: BbtMeasurementKind.sleepingWrist,
    );
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await tester.tap(
          find.bySemanticsLabel(_todayCellLabel(periodDay: false)),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Apple Watch · captured while you slept'),
          findsOneWidget,
        );
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

  Surface('birth_control_recalibration_screen — guided explainer', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedBirthControlSwitchMode(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openBirthControlSwitchScreen(tester);
        expect(
          find.widgetWithText(AppBar, 'After a birth-control change'),
          findsOneWidget,
        );
        await check(tester);
      },
    );
  }),

  // p7.5 — endometriosis mode: the pain/flare correlation view in its fullest
  // (chart + named phase) and empty states, plus the pain-logging sheet.
  Surface('endometriosis_screen — pain & flare correlation', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedEndometriosisModeWithFlares(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openEndometriosisScreen(tester);
        expect(find.widgetWithText(AppBar, 'Endometriosis'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('endometriosis_screen — nothing logged yet', (tester, check) async {
    final db = memoryDb();
    await _seedEndometriosisModeEmpty(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openEndometriosisScreen(tester);
        expect(find.widgetWithText(AppBar, 'Endometriosis'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('endometriosis_pain_sheet — log today\'s pain', (
    tester,
    check,
  ) async {
    final db = memoryDb();
    await _seedEndometriosisModeEmpty(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openEndometriosisScreen(tester);
        await tester.tap(find.text("Log today's pain"));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Log pain'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  // p7.6 — PMDD mode: the cycle-overlay view in its fullest (chart + luteal
  // read) and empty states, plus the daily rating sheet.
  Surface('pmdd_screen — ratings across your cycle', (tester, check) async {
    final db = memoryDb();
    await _seedPmddModeWithRatings(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPmddScreen(tester);
        expect(find.widgetWithText(AppBar, 'PMDD'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pmdd_screen — nothing rated yet', (tester, check) async {
    final db = memoryDb();
    await _seedPmddModeEmpty(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPmddScreen(tester);
        expect(find.widgetWithText(AppBar, 'PMDD'), findsOneWidget);
        await check(tester);
      },
    );
  }),

  Surface('pmdd_rating_sheet — rate today', (tester, check) async {
    final db = memoryDb();
    await _seedPmddModeEmpty(db);
    await pumpOlf(
      tester,
      overrides: screenNavOverrides(db),
      body: () async {
        await _openPmddScreen(tester);
        await tester.tap(find.text('Rate today'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Rate today'), findsOneWidget);
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
