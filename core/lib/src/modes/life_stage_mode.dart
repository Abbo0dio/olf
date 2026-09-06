/// The opt-in life-stage / condition modes added in Phase 7 (p7.1–p7.8).
///
/// A mode is a focused lens on the *same* underlying data — it changes what the
/// app surfaces and asks about, never the core logging model. Every mode is
/// **off by default** and turning one off never deletes data (see
/// `docs/plan/phases/phase-07.md`, "Phase-wide constraints").
///
/// Enablement is a typed key in the existing `app_settings` KV store — no
/// schema change. Each mode owns the key [settingKey] (`mode.<name>`), whose
/// value is `'true'` when enabled and absent / anything else when off.
enum LifeStageMode {
  /// p7.1 — tracks the return of the cycle after a pregnancy loss or birth.
  postpartum,

  /// p7.2 — week-by-week view + pregnancy symptom logging.
  pregnancy,

  /// p7.3 — trying to conceive: a daily fertility score + timing guidance.
  ttc,

  /// p7.4 — PCOS: irregular-cycle-aware UI + symptom-correlation views.
  pcos,

  /// p7.5 — endometriosis: pain mapping, flare tracking, cycle-phase correlation.
  endometriosis,

  /// p7.6 — PMDD: daily luteal-phase symptom rating + cycle-overlay charts.
  pmdd,

  /// p7.7 — perimenopause / menopause: variability view + symptom timeline.
  perimenopause,

  /// p7.8 — birth-control switching: guided prediction recalibration.
  birthControlSwitch;

  /// The `app_settings` key holding this mode's on/off flag.
  String get settingKey => 'mode.$name';
}

/// Read a mode flag's stored value. `'true'` (exactly) means enabled; `null`
/// or anything else means off — so every mode is off until deliberately
/// turned on.
bool lifeStageModeEnabled(String? storedValue) => storedValue == 'true';

/// The stored value to write for an on/off choice.
String lifeStageModeValue({required bool enabled}) =>
    enabled ? 'true' : 'false';
