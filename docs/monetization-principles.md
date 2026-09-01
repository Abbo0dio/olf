# Monetization principles

`requirements.md` §5 ("humane monetization") and §7 ("easy *stop asking me to
subscribe* control"). **olf sells nothing today** — no account, no paid tier, no
upsell surface anywhere in the app. This doc records the contracts that Phase 10
(monetization + AI assistant + advanced insights) inherits, put in place now so
the paid tier is built against an existing suppression path rather than bolting
one on afterwards.

## The "stop asking" control (p4.5)

There is a single persistent switch:

- **Setting key:** `SettingKeys.suppressSubscriptionPrompts` in
  `core/lib/src/settings/settings_repository.dart` (`app_settings` KV store).
  Absent / `'false'` / anything unrecognised ⇒ prompts **allowed**; only the
  exact string `'true'` suppresses.
- **Read it through one helper:** `subscriptionPromptsAllowed(String? raw)` in
  the same file — pure, `raw != 'true'`. The "absent = allowed" default and the
  fail-toward-allowed behaviour for malformed values live here and nowhere else.
- **App-side:** `subscriptionPromptsAllowedProvider`
  (`app/lib/src/monetization/subscription_prompt_providers.dart`) — a live
  `bool`, default `true`. `setSubscriptionPromptsSuppressed(ref, suppressed:)`
  writes it.
- **UI:** Settings → *Subscriptions* → **"Don't show subscription offers"**, a
  plain `SwitchListTile`. Turning it on is immediate and final until the user
  turns it back off. **No confirmation dialog, no "are you sure you'll miss
  out", no re-prompt, no nag on next launch.** Turning it back off is one tap.

## The hard gate for Phase 10+

**Every** subscription / upsell / paid-tier / "upgrade" prompt — dialog, banner,
bottom sheet, badge, interstitial, post-action nudge, anything — added in Phase
10 or later **MUST**:

1. Check `subscriptionPromptsAllowedProvider` (or, off the widget tree, the
   `subscriptionPromptsAllowed` core helper against the stored value), and
2. Render **nothing** — build no widget, show no toast, start no navigation —
   when it is `false`.

This is a **hard gate, not a preference**. It is not "show it less often" or
"show a smaller one". A suppressed user sees zero subscription prompting for the
life of the install unless they themselves turn the switch back off. A prompt
that cannot honour this must not ship.

Free core tracking is never gated by anything — this control only ever hides
*offers*, never *features*.

## Related

- `DEVELOPMENT_PLAN.md` Phase 10 ("no post-action upsell pop-ups, honour the
  p4.5 'stop asking' control") and its §9 backlog line.
- `requirements.md` §5, §7.
