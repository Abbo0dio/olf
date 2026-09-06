# Open questions

Move these into the Decisions Log once answered.

- Flutter vs. React Native/Expo — provisionally Flutter; revisit before p0.2 if the team's
  skills point the other way.
- AI assistant provider and on-device vs. zero-knowledge server model (Phase 10).
- Is the desktop shell Flutter-desktop or Tauri+`core` bridge? (Phase 13.)
- Do we ever pursue FDA / contraception positioning? (Phase 12 decision point.)
- Self-host the sync backend vs. managed? (Phase 9.)
- 2026-09-02 — Monetization: decided against, permanently. olf is free forever — no
  subscription, no paid tier, no billing. Phase 10 rescoped to AI assistant + advanced
  insights, both free. p4.5's "stop asking to subscribe" control reverted (PR #52) — it
  implied a paywall that will never exist. No B2B2C / employer / insurer channel either —
  olf is not sold to anyone. There is no revenue model; if one is ever needed it is a
  separate, explicit, and reversible-with-scrutiny decision. (B2B2C struck from Phase 12
  this PR.)

---
