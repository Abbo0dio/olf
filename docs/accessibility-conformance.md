# Accessibility conformance statement (WCAG 2.2 AA)

`requirements.md` §8. This is the Phase 5 accessibility exit-gate evidence: a
success-criterion-by-success-criterion record of where olf stands against
**WCAG 2.2 Level A + AA**, with a pointer to the test or the screen that backs
each claim.

- **Scope:** the olf Android/iOS app (`app/`) and the domain layer it renders
  (`core/`). One target platform pair, one language (English), offline, no
  account, no web surface.
- **Status values:** **Supports** — no known gap; **Partially** — a real,
  named gap with a tracked follow-up (see `DEVELOPMENT_PLAN.md` §9); **Not
  applicable** — the criterion covers content or a mechanism olf does not have.
- Honesty over optics: a "Partially" with a follow-up is preferred to a
  generous "Supports".

Most rows are exercised by the automated a11y suite under
[`app/test/a11y/`](../app/test/a11y/) — `screen_guidelines_test.dart`
(labels + 48dp tap targets + text contrast, every top-level surface),
`semantics_labels_test.dart` (no unlabelled operable node),
`focus_order_test.dart` + `keyboard_nav_test.dart` (keyboard reachability,
activation, order, no trap), `text_scaling_test.dart` (reflow at 1.0/1.5/2.0×
text), `theme_contrast_test.dart` (WCAG contrast over every `ColorScheme`
role pair, both themes) — plus `core/test/a11y/contrast_test.dart` for the
contrast maths. All run in the required `CI OK` check.

## Principle 1 — Perceivable

| SC | Level | Status | Evidence |
|----|-------|--------|----------|
| 1.1.1 Non-text Content | A | Supports | Every icon button carries a `tooltip`; calendar cells are `Semantics(button:, label:)`. `semantics_labels_test.dart` fails on any operable node with no label/value/tooltip; `screen_guidelines_test.dart` runs `labeledTapTargetGuideline`. No informational images. |
| 1.2.1 Audio-only / Video-only (Prerecorded) | A | Not applicable | olf ships no audio or video. **Enforced by design:** the `core` `MediaItem` contract + the `CaptionedMedia` widget (p5.2) make a transcript non-optional, so Phase 11 media cannot ship without a text alternative. |
| 1.2.2 Captions (Prerecorded) | A | Not applicable | No media ships. **Enforced by design:** `MediaItem` / `CaptionTrack` (p5.2, `core/lib/src/a11y/captions.dart`, tests in `core/test/a11y/captions_test.dart`) make a synchronised caption track a `required`, non-empty, chronological field — a Phase 11 media slice cannot compile without it. |
| 1.2.3 Audio Description / Media Alternative (Prerecorded) | A | Not applicable | No media ships. **Enforced by design:** `MediaItem.transcript` is `required` and asserted non-empty (p5.2); a caption track alone does not satisfy the contract. |
| 1.2.4 Captions (Live) | AA | Not applicable | No live media, and none is planned. |
| 1.2.5 Audio Description (Prerecorded) | AA | Not applicable | No media ships. **Enforced by design:** the mandatory `MediaItem.transcript` (p5.2) is the media alternative carrying description of visual information; a Phase 11 audio-description track would layer on top. |
| 1.3.1 Info and Relationships | A | Supports | Native Material widgets (`ListTile`, `SwitchListTile`, `RadioListTile`, `AppBar` titles, section headers) carry role/label/state in the semantics tree; `SwitchListTile`/`RadioListTile` merge their control so the row is one labelled node. |
| 1.3.2 Meaningful Sequence | A | Supports | Reading order follows the widget tree; `focus_order_test.dart` asserts traversal order on the first-run form and the settings list. |
| 1.3.3 Sensory Characteristics | A | Supports | Instructions never rely on shape/position/colour alone ("tap everything that applies", not "tap the button on the right"). Enforced in spirit by the p1.9 copy sweep. |
| 1.3.4 Orientation | AA | Supports | No orientation lock in `AndroidManifest.xml` or `Info.plist`; layouts are scroll-based and reflow (see 1.4.10). |
| 1.3.5 Identify Input Purpose | AA | Supports | The only entry fields are the PIN, the basal-temperature reading, and a symptom name — none collect information *about the user* in the WCAG input-purpose taxonomy, so there is nothing to auto-populate. |
| 1.4.1 Use of Color | A | Supports | State is never colour-only: period days carry a label + the `_FlowBar` glyph, selected chips use the Material selected state (checkmark + fill), errors use `errorText` strings. |
| 1.4.2 Audio Control | A | Not applicable | No auto-playing audio. |
| 1.4.3 Contrast (Minimum) | AA | Supports | `theme_contrast_test.dart` asserts ≥ 4.5:1 for text / ≥ 3:1 for large text over every `ColorScheme` role pair olf paints, in **both** light and dark; `screen_guidelines_test.dart` runs `textContrastGuideline` on every rendered surface. All pass with the M3 `fromSeed` palette untouched. |
| 1.4.4 Resize Text | AA | Supports | `text_scaling_test.dart` pumps all 16 surfaces at 1.5× and 2.0× OS text scale with zero overflow (p5.1b). |
| 1.4.5 Images of Text | AA | Supports | No images of text anywhere; all text is live `Text`. |
| 1.4.10 Reflow | AA | Supports | Content is `ListView` / `SingleChildScrollView` throughout; no fixed-width containers force horizontal scrolling; verified at 2.0× text by `text_scaling_test.dart` (p5.1b). |
| 1.4.11 Non-text Contrast | AA | Supports | `outline` on `surface` asserted ≥ 3:1 in `theme_contrast_test.dart`; UI component boundaries and icons derive from the same scheme roles. |
| 1.4.12 Text Spacing | AA | Supports | No `Text` uses a fixed `height`/`letterSpacing` override that would clip under user spacing; text containers grow with their content (same reflow property verified by `text_scaling_test.dart`). |
| 1.4.13 Content on Hover or Focus | AA | Supports | The only hover/focus-triggered content is Material `Tooltip`, which is dismissable (Esc), hoverable, and persistent by default. |

## Principle 2 — Operable

| SC | Level | Status | Evidence |
|----|-------|--------|----------|
| 2.1.1 Keyboard | A | Supports | `keyboard_nav_test.dart` reaches and activates the primary action on a form, a list row, and a FAB with Tab + Enter; no pointer-only path exists for a primary verb. |
| 2.1.2 No Keyboard Trap | A | Supports | `keyboard_nav_test.dart` ("no keyboard trap") tabs 60× through settings and confirms focus keeps moving and cycles rather than sticking; modals are standard `showDialog` / `showModalBottomSheet` with a working dismiss. |
| 2.1.4 Character Key Shortcuts | A | Not applicable | olf defines no single-character key shortcuts. |
| 2.2.1 Timing Adjustable | A | Supports | No time limits on any interaction today. (The p5.3 inactivity auto-lock, when it lands, ships with an adjustable duration + a pre-expiry warning — tracked in that slice.) |
| 2.2.2 Pause, Stop, Hide | A | Supports | No moving, blinking, scrolling, or auto-updating content. `CircularProgressIndicator` is a brief loading state only. |
| 2.3.1 Three Flashes or Below Threshold | A | Supports | Nothing flashes. |
| 2.4.1 Bypass Blocks | A | Not applicable | Single-screen native views with an `AppBar`; there is no repeated block of navigation to bypass. |
| 2.4.2 Page Titled | A | Supports | Every screen has a titled `AppBar` (or, for sheets, a heading `Text` as the first child); `theme_render_test.dart` / `screen_nav.dart` assert titles. |
| 2.4.3 Focus Order | A | Supports | `focus_order_test.dart`: first-run policy-link → acknowledge; PIN → Confirm → acknowledge; settings Appearance → Privacy. |
| 2.4.4 Link Purpose (In Context) | A | Supports | The one in-content link ("Read the full privacy policy") is self-describing; policy/education entries name their destination. |
| 2.4.5 Multiple Ways | AA | Not applicable | A linear utility app with no site-like structure; every destination is one level from the home scaffold or Settings. |
| 2.4.6 Headings and Labels | AA | Supports | Section headers in Settings and sheet headings are descriptive; every field has a visible label (`InputDecoration.labelText`). |
| 2.4.7 Focus Visible | AA | Supports | Material 3 focus highlight / overlay on every focusable widget; `keyboard_nav_test.dart` confirms each Tab lands on a named, visible control. |
| 2.4.11 Focus Not Obscured (Minimum) | AA | Supports | No sticky/overlapping chrome; a focused control in a scroll view is scrolled into the viewport. FABs sit in the `Scaffold` gutter and do not cover list focus targets. |
| 2.5.1 Pointer Gestures | A | Supports | All interactions are single-tap; no multipoint or path-based gesture is required. (Reorder drag — see 2.5.7.) |
| 2.5.2 Pointer Cancellation | A | Supports | Standard Material buttons act on up-event and are cancellable by dragging off before release. |
| 2.5.3 Label in Name | A | Supports | Accessible names match or contain the visible label (`labeledTapTargetGuideline` in `screen_guidelines_test.dart`; visible-text labels used verbatim as semantic labels). |
| 2.5.4 Motion Actuation | A | Not applicable | No function is triggered by device motion. |
| 2.5.7 Dragging Movements | AA | **Partially** | Reordering the symptom list in `manage_symptoms_page.dart` is drag-only (`ReorderableDragStartListener`); there is no single-tap "move up / move down" alternative for a pointer user who cannot drag. Screen-reader users get `ReorderableListView`'s built-in move actions. Follow-up: add explicit move controls — `DEVELOPMENT_PLAN.md` §9 (p5.1c follow-ups). |
| 2.5.8 Target Size (Minimum) | AA | Supports | `screen_guidelines_test.dart` runs `androidTapTargetGuideline` + `iOSTapTargetGuideline` (48dp) unskipped on every surface — stricter than the 24×24 CSS-px minimum. |

## Principle 3 — Understandable

| SC | Level | Status | Evidence |
|----|-------|--------|----------|
| 3.1.1 Language of Page | A | Supports | Single-language (English) app; Flutter reports the platform locale to assistive technology for TTS. |
| 3.1.2 Language of Parts | AA | Not applicable | All content is in one language. |
| 3.2.1 On Focus | A | Supports | Focusing a control never changes context; navigation happens only on explicit activation (verified by `keyboard_nav_test.dart`). |
| 3.2.2 On Input | A | Supports | Changing a switch/radio/segmented control updates state in place; it never navigates or submits. The Appearance control re-themes without moving the user. |
| 3.2.3 Consistent Navigation | AA | Supports | The home `AppBar` (Medications, Settings) and back navigation are identical on every visit; Settings ordering is fixed. |
| 3.2.4 Consistent Identification | AA | Supports | Icons/labels are reused consistently — "Remove" (trash), "Rename" (pencil), "Settings" (gear) mean the same thing everywhere. |
| 3.2.6 Consistent Help | A | Supports | The only help-like content — the three privacy explainers — is always reached the same way (Settings → Learn how olf protects…), in the same position. |
| 3.3.1 Error Identification | A | Supports | Field errors are text via `InputDecoration.errorText` (PIN mismatch, out-of-range temperature, invalid period range); not colour-only. |
| 3.3.2 Labels or Instructions | A | Supports | Every field has a persistent `labelText`; sheets carry a one-line instruction ("Tap everything that applies."). |
| 3.3.3 Error Suggestion | AA | Supports | Errors say how to fix it ("Choose a code different from your main PIN", "PINs don't match", range hints on temperature). |
| 3.3.4 Error Prevention (Legal, Financial, Data) | AA | Supports | Every destructive action is confirmed via an `AlertDialog` — delete period, remove symptom, remove pregnancy entry, turn off app lock, turn off decoy PIN, change retention window, wipe data. |
| 3.3.7 Redundant Entry | A | Supports | No step re-asks for information already given in the same session. PIN confirmation is the essential-re-entry exception the SC allows. |
| 3.3.8 Accessible Authentication (Minimum) | AA | Supports | The memorised PIN has an alternative authentication mechanism — biometric unlock (p2.1). The PIN field does not block paste and imposes no transcription/puzzle step. |

## Principle 4 — Robust

| SC | Level | Status | Evidence |
|----|-------|--------|----------|
| 4.1.1 Parsing | A | Not applicable | Obsolete/removed in WCAG 2.2, and not meaningful for a native rendered UI (no markup to parse). |
| 4.1.2 Name, Role, Value | A | Supports | Native Material widgets expose name/role/state; `semantics_labels_test.dart` + `screen_guidelines_test.dart` guard names; toggles expose checked state through the merged list-tile node. |
| 4.1.3 Status Messages | AA | **Partially** | The calendar month change announces via `SemanticsService.announce` + a `liveRegion: true` node. The `ScaffoldMessenger` `SnackBar` confirmations elsewhere ("App lock is on.", "… removed.") are visible but not wrapped in a live region, so a screen reader may not speak them without focus movement. Follow-up: route SnackBar confirmations through a live region / `SemanticsService.announce` — `DEVELOPMENT_PLAN.md` §9 (p5.1c follow-ups). |

## Summary

| Status | Count |
|--------|-------|
| Supports | 39 |
| Partially | 2 (SC 2.5.7, SC 4.1.3) |
| Not applicable | 9 |

The two "Partially" rows are tracked as p5.1c follow-ups in
`DEVELOPMENT_PLAN.md` §9 and do not block the Phase 5 exit gate: both have a
working path for assistive-technology users today, and neither touches health
data or the privacy posture.

_Last reviewed: 2026-09-03 (p5.2 — captions rows updated for the `MediaItem` contract; p5.1c otherwise), reviewer: worker: phase5._
