/// In-app privacy education (p2.7) — three short, honest, non-alarming
/// explainers, kept as named constants (same pattern as
/// `privacy_policy_content.dart` and `onboarding/disclaimers.dart`) so a content
/// test can assert every point is on screen and the p1.9 copy-lint has one
/// place to look.
///
/// These are **education, not the policy**. p2.5's `PrivacyPolicyScreen` holds
/// the commitments and the consent switches; this file explains the
/// consumer-health-privacy landscape and — the point of the slice — the
/// concrete steps to delete everything, because only a small fraction of people
/// ever take a protective action.
///
/// Tone: plain, second person, calm. No fear-mongering (§4 / §9(12)).
library;

/// One explainer: an [id] (stable, used for routing + the delete hand-off), a
/// [title], a one-line [summary] for the index list, and [body] paragraphs.
class PrivacyExplainer {
  const PrivacyExplainer({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> body;
}

/// Section heading wherever the three explainers are listed.
const String privacyEducationTitle = 'Privacy basics';

/// One-line intro for the index.
const String privacyEducationIntro =
    'Three short things worth knowing about your data — and how to remove it.';

/// Row label / link used from the privacy policy and from Settings.
const String privacyEducationEntryLabel = 'Privacy basics';
const String privacyEducationEntrySubtitle =
    'The HIPAA gap, law-enforcement reality, and how to delete everything.';

const PrivacyExplainer hipaaGapExplainer = PrivacyExplainer(
  id: 'hipaa-gap',
  title: "Why HIPAA doesn't cover olf",
  summary:
      'A consumer app is not a "covered entity" — what that does and '
      "doesn't mean.",
  body: <String>[
    'HIPAA is often assumed to protect anything health-related. It does not. '
        'HIPAA rules apply to "covered entities" — healthcare providers, health '
        'plans, and the contractors who handle data for them. A cycle-tracking '
        'app you install yourself is none of those, so HIPAA places no '
        'obligations on what happens to what you log here.',
    'In practice that has meant there is no federal health-privacy law forcing '
        'a period app to protect your entries, and some apps have used that gap '
        'to share or sell cycle data.',
    'What it means for olf: your privacy here does not depend on HIPAA at all. '
        'Your entries stay in an encrypted database on this device, with no '
        'account and nothing on a server — there is nothing to share or sell '
        'whether HIPAA applies or not.',
    'State consumer-health-privacy laws — Washington\'s My Health My Data Act '
        'and Nevada SB370 — do reach apps like this one, and olf is built to '
        'meet them. See the privacy policy for the specifics.',
  ],
);

const PrivacyExplainer lawEnforcementExplainer = PrivacyExplainer(
  id: 'law-enforcement',
  title: 'If your data were ever requested',
  summary:
      'What could be compelled — and why there is nothing on a server to '
      'hand over.',
  body: <String>[
    'Cycle data has been sought in investigations, including after abortion '
        'bans. It is a reasonable thing to think about calmly rather than avoid.',
    'From the maker of olf, essentially nothing could be compelled. There is no '
        'account, no server-side log, and no cloud copy — your entries are '
        'never received by anyone. A legal request would be answered that valid '
        'legal process is required and, truthfully, that no such data is held.',
    'What still exists is the encrypted database on this device. Someone with '
        'your unlocked phone — or who can compel your PIN or biometrics — can '
        'open the app. The realistic exposure is a seized or borrowed device, '
        'not a subpoena to a server.',
    'You control several mitigations: the PIN and biometric lock; the decoy '
        'PIN, which opens a separate empty space if you are forced to unlock; '
        'and the auto-delete window, so older entries are not there to be '
        'found. This is context, not legal advice.',
  ],
);

/// The concrete, numbered steps for the delete explainer. Rendered as an
/// ordered list; the first step's hand-off is a real button to Backup &
/// restore (see [deleteEverythingBackupAction]).
const List<String> deleteEverythingSteps = <String>[
  'Optional: export an encrypted backup first, if you want to keep a copy you '
      'control. Settings → Backup & restore → "Create an encrypted '
      'backup". You choose where the file is saved and set its passphrase.',
  'To clear out older entries on a schedule, set an auto-delete window. '
      'Settings → "Auto-delete old entries". Anything past the window is '
      'deleted and left out of future backups.',
  'To remove everything now, uninstall olf. That deletes the encrypted '
      'database and the key that opens it — nothing recoverable is left on the '
      'device, and there was never a copy anywhere else. Reinstalling starts '
      'from an empty app.',
];

/// Button label for the delete explainer's hand-off to the real export screen.
const String deleteEverythingBackupAction = 'Open Backup & restore';

const PrivacyExplainer deleteEverythingExplainer = PrivacyExplainer(
  id: 'delete-everything',
  title: 'How to delete everything',
  summary:
      'The concrete steps: export first if you want a copy, then uninstall '
      'removes it all.',
  body: <String>[
    'Everything olf holds is in one encrypted database on this device. There '
        'is no cloud copy to chase down and no account to close.',
    'Follow the steps below. If you have set a decoy PIN, uninstalling removes '
        'that separate space too.',
  ],
);

/// All three, in the order they are shown.
const List<PrivacyExplainer> privacyExplainers = <PrivacyExplainer>[
  hipaaGapExplainer,
  lawEnforcementExplainer,
  deleteEverythingExplainer,
];
