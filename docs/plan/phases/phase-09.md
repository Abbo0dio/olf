### Phase 9 — Optional zero-knowledge encrypted sync

**Requirement refs:** §3, §10, Matrix WOW-FACTOR. Slices:

- **p9.1** Sync protocol design in `core` — end-to-end / zero-access encryption; server never
  sees plaintext; key derived from a user secret, not stored server-side.
- **p9.2** Account-optional identity (key-based / passphrase), no email required.
- **p9.3** Backend service — minimal, self-hostable if feasible; stores ciphertext blobs only.
- **p9.4** Multi-device sync with conflict resolution that never silently discards a user
  correction.
- **p9.5** Deletion propagation — delete means delete, including backups and any processors
  (MHMDA requirement).
- **p9.6** Local-first remains the **default**; sync is explicitly opt-in with a clear
  explanation of the trade-off.

**Exit gate:** two devices stay in sync through an untrusted server; server compromise exposes
no health data; deletion verified end-to-end.

---
