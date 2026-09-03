/// olf_core — pure-Dart domain layer.
///
/// This library has **no Flutter dependency** on purpose (see DEVELOPMENT_PLAN.md
/// §3): the mobile app and the future desktop shell both consume it.
library;

export 'src/a11y/captions.dart';
export 'src/a11y/contrast.dart';
export 'src/backtest/backtest_harness.dart';
export 'src/backtest/backtest_metrics.dart';
export 'src/backtest/correction_response.dart';
export 'src/backtest/synthetic_history.dart';
export 'src/backup/backup_cipher.dart';
export 'src/backup/backup_document.dart';
export 'src/backup/backup_service.dart';
export 'src/bbt/bbt_chart.dart';
export 'src/bbt/bbt_repository.dart';
export 'src/bbt/drift_bbt_repository.dart';
export 'src/bbt/temperature.dart';
export 'src/cycle/cycle.dart';
export 'src/cycle/cycle_derivation.dart';
export 'src/cycle/pregnancy_event.dart';
export 'src/date_math.dart';
export 'src/db/app_database.dart';
export 'src/db/database_key_store.dart';
export 'src/db/tables.dart'
    show
        AppSettings,
        BbtEntries,
        BirthControlEntries,
        BirthControlMethod,
        CervicalMucusEntries,
        CervicalMucusType,
        ClotSize,
        CycleEventType,
        CycleEvents,
        DailyFlows,
        DailySymptomEntries,
        FlowIntensity,
        Medications,
        Periods,
        ReminderKind,
        Reminders,
        SymptomTypes,
        kBuiltInSymptomNames;
export 'src/flow/daily_flow_repository.dart';
export 'src/flow/drift_daily_flow_repository.dart';
export 'src/meds/birth_control.dart';
export 'src/meds/birth_control_repository.dart';
export 'src/meds/drift_birth_control_repository.dart';
export 'src/meds/drift_medication_repository.dart';
export 'src/meds/medication.dart';
export 'src/meds/medication_repository.dart';
export 'src/mucus/cervical_mucus.dart';
export 'src/mucus/cervical_mucus_repository.dart';
export 'src/mucus/drift_cervical_mucus_repository.dart';
export 'src/mucus/fertile_window_signal.dart';
export 'src/period/drift_period_repository.dart';
export 'src/period/period_repository.dart';
export 'src/period/period_validation.dart';
export 'src/personalization/pronouns.dart';
export 'src/prediction/adaptive_predictor.dart';
export 'src/prediction/date_range.dart';
export 'src/prediction/prediction_delta.dart';
export 'src/prediction/predictor.dart';
export 'src/prediction/robust_predictor.dart';
export 'src/reminders/drift_logging_activity_repository.dart';
export 'src/reminders/drift_reminder_repository.dart';
export 'src/reminders/logging_activity_repository.dart';
export 'src/reminders/preferred_hour.dart';
export 'src/reminders/quiet_hours.dart';
export 'src/reminders/reminder_planning.dart';
export 'src/reminders/reminder_repository.dart';
export 'src/reminders/reminder_schedule.dart';
export 'src/repository/cycle_event_repository.dart';
export 'src/repository/drift_cycle_event_repository.dart';
export 'src/retention/retention_service.dart';
export 'src/retention/retention_window.dart';
export 'src/security/pin.dart';
export 'src/security/pin_store.dart';
export 'src/settings/drift_settings_repository.dart';
export 'src/settings/settings_repository.dart';
export 'src/symptom/drift_symptom_repository.dart';
export 'src/symptom/symptom_repository.dart';
export 'src/symptom/symptom_validation.dart';
