/// olf_core — pure-Dart domain layer.
///
/// This library has **no Flutter dependency** on purpose (see DEVELOPMENT_PLAN.md
/// §3): the mobile app and the future desktop shell both consume it.
library;

export 'src/cycle/cycle.dart';
export 'src/cycle/cycle_derivation.dart';
export 'src/date_math.dart';
export 'src/db/app_database.dart';
export 'src/db/database_key_store.dart';
export 'src/db/tables.dart'
    show
        ClotSize,
        CycleEventType,
        CycleEvents,
        DailyFlows,
        DailySymptomEntries,
        FlowIntensity,
        Periods,
        SymptomTypes,
        kBuiltInSymptomNames;
export 'src/flow/daily_flow_repository.dart';
export 'src/flow/drift_daily_flow_repository.dart';
export 'src/period/drift_period_repository.dart';
export 'src/period/period_repository.dart';
export 'src/period/period_validation.dart';
export 'src/prediction/date_range.dart';
export 'src/prediction/predictor.dart';
export 'src/prediction/robust_predictor.dart';
export 'src/repository/cycle_event_repository.dart';
export 'src/repository/drift_cycle_event_repository.dart';
export 'src/symptom/drift_symptom_repository.dart';
export 'src/symptom/symptom_repository.dart';
export 'src/symptom/symptom_validation.dart';
