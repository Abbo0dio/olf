### Phase 10 — AI assistant + advanced insights

**Requirement refs:** §2. Slices:

- **p10.1** AI health assistant — 24/7 Q&A. Decide the provider (consult `claude-api` skill);
  hard constraint: no health data leaves the device to a third party without zero-knowledge or
  on-device processing. Humane, non-alarming messaging; never an automated "diagnosis".
- **p10.2** Advanced personalized insights — pattern detection, cycle × sleep ×
  nutrition synthesis, condition-mode correlation insights.

**Exit gate:** AI assistant privacy design documented in the threat model (no health data to a
third party without zero-knowledge or on-device processing); advanced insights are useful and
non-alarming — worded as patterns and correlations, never as a diagnosis. Free, like everything
else.

---
