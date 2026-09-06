### Phase 8 — Passive wearable integration

**Requirement refs:** §2, §10. Slices:

- **p8.1** Apple Watch companion app (Swift/SwiftUI) — passive overnight wrist-temperature
  capture feeding the Flutter app via HealthKit.
- **p8.2** Oura integration.
- **p8.3** Garmin integration.
- **p8.4** Whoop integration.
- **p8.5** Passive cycle-phase inference from temperature + HRV + sleep, reducing manual logging;
  still fully correctable (Phase 3 engine).
- **p8.6** Graceful multi-source handling (wearable + manual + Health platform) without conflicts.

**Exit gate:** Apple Watch companion + at least one third-party wearable in production; passive
inference measured against the Phase 3 backtester.

---
