### Phase 13 — Desktop app provision (separate & lean)

**Goal:** a future desktop app **without adding any weight to mobile**.

- **p13.1** Confirm `core` is fully platform-agnostic (no mobile-only assumptions leaked in).
- **p13.2** Separate desktop shell (Flutter desktop, or Tauri consuming a `core` FFI/bridge —
  decide then) as its **own package / repo target**, not a dependency of `app`.
- **p13.3** Desktop uses the Phase 9 sync (or local import/export) to get data — no new backend.
- **p13.4** Minimal feature set first (view + log + predictions); parity is not a goal.

**Exit gate:** desktop build exists and reuses `core`; mobile install size and dependency
count are unchanged.

---
