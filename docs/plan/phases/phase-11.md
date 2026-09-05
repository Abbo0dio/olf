### Phase 11 — Educational content & privacy-safe community

**Requirement refs:** §2. Slices:

- **p11.1** Content system with **named medical reviewers** shown per article; offline-cacheable.
- **p11.2** Content notifications as their own opt-in category (ties to p4.1); never used as
  upsell bait.
- **p11.3** Privacy-safe anonymous community (à la "Secret Chats") — no real identities,
  minimal metadata.
- **p11.4** Moderation tooling and reporting.

**Captions gate (from p5.2):** any Phase 11 slice that adds in-app video or audio **must**
route it through `core`'s `MediaItem` / `CaptionTrack` and the app's `CaptionedMedia` widget.
Both make a synchronised caption track **and** a plain-text transcript `required`,
non-nullable fields — a media slice that omits either will not compile. Shipping media without
captions + a transcript is a merge blocker; see `docs/accessibility-conformance.md`
(SC 1.2.1–1.2.5).

**Exit gate:** content is attributed and accessible; community is anonymous, moderated, and
opt-in.

---
