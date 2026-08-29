/// First-run disclaimer copy (p1.8), reviewed against `requirements.md` §3 and
/// §6. Kept as named constants so a content test can assert every point is
/// actually shown, and so p1.9's copy sweep has one place to look.
///
/// Tone: plain and non-alarming. It states what is true — local storage, no
/// account, no trackers, not a medical device — without fear-mongering.
library;

/// Screen heading.
const String disclaimerTitle = 'A few things first';

/// Ordered (heading, body) pairs shown as a list on the first-run screen.
const List<(String, String)> disclaimerPoints = <(String, String)>[
  (
    'Your data stays on this device',
    'olf has no account and no cloud. Everything you log is stored, encrypted, '
        'on this device only. We never sell or share it, and there is nothing '
        'on a server for anyone to request.',
  ),
  (
    'HIPAA does not apply here',
    'Cycle-tracking apps generally are not covered by HIPAA. Your privacy here '
        'comes from how olf is built — on-device storage and no third-party '
        'analytics or advertising — not from health-privacy law.',
  ),
  (
    'Not medical advice',
    "olf's predictions and insights are estimates based on what you log. They "
        'are not a diagnosis. Check anything that matters with a clinician.',
  ),
  ('Not a contraceptive', 'Do not rely on olf to prevent or plan a pregnancy.'),
];

/// The primary button that records acknowledgement and enters the app.
const String disclaimerAcknowledgeLabel = 'Got it — continue';

/// Label for the optional PIN opt-in on the same screen.
const String disclaimerPinOptInLabel = 'Lock olf with a PIN';

/// Helper text under the PIN opt-in.
const String disclaimerPinOptInHint =
    'A short numeric code asked each time you open olf. You can change or remove '
    'it later. This is a screen lock, not extra encryption.';
