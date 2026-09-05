# Cross-cutting / always-on

These are not phases; they are checked every phase.

### Compliance ledger

Maintain a table (fill as work lands): requirement → where addressed → status.

- Non-medical disclaimers present and correct (unless Phase 12 FDA decision changes this).
- MHMDA: standalone consumer-health privacy policy linked from home/first-run; separate opt-in
  for collection and sharing; written authorization before any sale (there is none planned);
  right to deletion incl. backups/processors; no geofencing of health facilities.
- Nevada consumer-health law alignment.
- GDPR (EU) and CCPA (California) data-subject rights.
- FTC Health Breach Notification Rule process.
- No third-party ad/analytics SDKs (enforced by the p0.3 gate).
- Marketing/accuracy claims are substantiated (ASA precedent).
- ISO 27001 track (Phase 12).

### Release / store readiness (revisit before each public release)

- App Store / Play data-safety forms match reality (no data collection to declare, ideally).
- Backup/restore (p1.10) shipped before first release.
- Crash reporting, if any, is self-hosted / on-device and PHI-free — or omitted.
- Accessibility statement.
- Support + data-deletion request path.

### Engineering hygiene

- `core` stays Flutter-free and platform-agnostic (protects Phase 13).
- Every platform SDK sits behind an interface in `core`.
- Schema changes always ship a migration + a migration test.
- Performance budget (§3) checked in CI.

---
