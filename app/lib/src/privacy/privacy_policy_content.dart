/// Standalone privacy-policy copy (p2.5), reviewed against `requirements.md` §3
/// and §6, and aligned with consumer-health-privacy laws — Washington's My
/// Health My Data Act (MHMDA) and Nevada SB370.
///
/// Kept as named constants, like `onboarding/disclaimers.dart`, so a content
/// test can assert every commitment and choice is actually on screen, and so the
/// p1.9 copy sweep has one place to look. Educational deep-dives (the HIPAA gap,
/// law-enforcement reality, a delete walkthrough) are **p2.7**, not here —
/// this screen is the policy itself plus the consent switches.
///
/// Tone: plain, honest, second person, non-alarming. It states what is true.
library;

/// Screen + Settings row heading.
const String privacyPolicyTitle = 'Privacy policy';

/// Human-readable date this copy was last reviewed. Update on any wording
/// change (a content test checks it is a non-empty, four-digit-year string).
const String privacyPolicyLastUpdated = 'Last reviewed 31 August 2026.';

/// Opening paragraph.
const String privacyPolicyIntro =
    'This is the whole policy — there is no separate website version. olf keeps '
    'everything you log on this device, encrypted, with no account and no '
    'server. The points below are commitments, not marketing.';

/// Ordered (heading, body) commitments. Each heading and a distinctive phrase
/// from each body is asserted by the content test.
const List<(String, String)> privacyPolicySections = <(String, String)>[
  (
    'Everything stays on your device',
    'olf has no account, no sign-in and no cloud. What you log is stored in an '
        'encrypted database on this device only. Nothing is uploaded, and there '
        'is nothing on a server anywhere with your name or your data on it.',
  ),
  (
    'We never sell your data',
    'We do not sell, rent or trade your information to anyone, for any price, '
        'ever. There is no exception for a change of ownership or an "anonymous" '
        'data set.',
  ),
  (
    'We do not share it either',
    'No advertising networks, no analytics providers, no data brokers, no '
        '"partners". olf ships with no third-party tracking or advertising code '
        '— a dependency check in the build enforces that on every change.',
  ),
  (
    'If someone asks us for your data',
    'A government body, a court or anyone else would be told that we require '
        'valid legal process. And because your entries never leave your device, '
        'there is nothing for us to hand over even if we were compelled to — we '
        'cannot produce what we do not hold.',
  ),
  (
    'Your consumer-health-data rights',
    'olf is built to meet Washington\'s My Health My Data Act and Nevada SB370: '
        'we collect and share no health data without your specific opt-in '
        'consent (see "Your choices" below), and that consent is off by '
        'default. You can see all of your data in the app, export an encrypted '
        'copy at any time, and delete it — set an auto-delete window in '
        'Settings, or remove everything at once by uninstalling olf.',
  ),
  (
    'What we would ever collect',
    'Right now: nothing. If a future version ever proposes collecting on-device '
        'usage metrics, or sharing anything with a third party, it will be '
        'listed here, it will be off until you turn it on, and turning it off '
        'again will stop it.',
  ),
  (
    'Children',
    'olf is not directed at children under 13 and we knowingly collect nothing '
        'from anyone — there is no collection to speak of.',
  ),
  (
    'Changes to this policy',
    'If this wording changes, the "last reviewed" date above changes with it, '
        'and any new data practice will be opt-in. Continued use never counts '
        'as agreement to new collection.',
  ),
];

/// Sub-heading above the two consent switches.
const String privacyChoicesHeading = 'Your choices';

/// Intro line for the choices block.
const String privacyChoicesIntro =
    'Both of these are off, and olf does nothing that needs them today. They '
    'are here so any future change is your decision, not ours.';

/// (a) Local analytics / collection opt-in.
const String analyticsOptInLabel = 'Allow on-device usage analytics';
const String analyticsOptInHint =
    'If a future version adds anonymous, on-device metrics about which screens '
    'you use, this permits it. Nothing is collected while this is off, and '
    'nothing leaves your device regardless.';

/// (b) Future third-party data sharing opt-in.
const String dataSharingOptInLabel = 'Allow sharing data with third parties';
const String dataSharingOptInHint =
    'olf shares nothing today. This stays off unless you deliberately turn it '
    'on for a specific feature that names the recipient and the purpose.';

/// Shown under the switches.
const String privacyChoicesFootnote =
    'Turning either of these off always takes effect immediately.';

/// Settings-row subtitle.
const String privacyPolicySettingsSubtitle =
    'How olf handles your data, and your choices.';

/// First-run link text.
const String privacyPolicyFirstRunLink = 'Read the full privacy policy';
