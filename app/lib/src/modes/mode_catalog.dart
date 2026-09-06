import 'package:olf_core/olf_core.dart';

/// User-facing name + one-line description for each Phase 7 [LifeStageMode],
/// shown in the Settings → Modes section (p7.1).
///
/// Copy is plain, non-clinical and non-diagnostic (see
/// `docs/plan/phases/phase-07.md`, "No diagnosis, no alarm"). Only the
/// postpartum mode has a screen wired in p7.1; the rest are listed so the
/// framework is visible and each later slice only has to fill in its screen.
({String title, String description}) modeCatalogEntry(LifeStageMode mode) =>
    switch (mode) {
      LifeStageMode.postpartum => (
        title: 'Postpartum',
        description:
            'Follow your cycle coming back after a loss or a birth, instead '
            'of one long gap.',
      ),
      LifeStageMode.pregnancy => (
        title: 'Pregnancy',
        description:
            'A week-by-week view from a start date you enter — last period, '
            'due date, or conception date.',
      ),
      LifeStageMode.ttc => (
        title: 'Trying to conceive',
        description:
            'A daily fertility estimate from your own patterns, and plain '
            'timing notes.',
      ),
      LifeStageMode.pcos => (
        title: 'PCOS',
        description:
            'A UI that expects irregular cycles, and views of how your '
            'symptoms track your cycle.',
      ),
      LifeStageMode.endometriosis => (
        title: 'Endometriosis',
        description:
            'Log pain and flares and see how they line up with cycle phase. '
            'Coming soon.',
      ),
      LifeStageMode.pmdd => (
        title: 'PMDD',
        description:
            'A quick daily rating and a chart of it across your cycles. '
            'Coming soon.',
      ),
      LifeStageMode.perimenopause => (
        title: 'Perimenopause',
        description:
            'A view built around rising cycle variability and longer gaps. '
            'Coming soon.',
      ),
      LifeStageMode.birthControlSwitch => (
        title: 'Birth-control change',
        description:
            'A gentler recalibration period after you start or stop hormonal '
            'birth control, instead of a confident forecast built on '
            'pre-change cycles.',
      ),
    };

/// Whether this mode has an interactive screen in the current build. Postpartum
/// (p7.1), pregnancy (p7.2a), TTC (p7.3), PCOS (p7.4) and birth-control change
/// (p7.8) do; the others can still be toggled so their state is ready when their
/// slice lands.
bool modeHasScreen(LifeStageMode mode) => switch (mode) {
  LifeStageMode.postpartum ||
  LifeStageMode.pregnancy ||
  LifeStageMode.ttc ||
  LifeStageMode.pcos ||
  LifeStageMode.birthControlSwitch => true,
  _ => false,
};
