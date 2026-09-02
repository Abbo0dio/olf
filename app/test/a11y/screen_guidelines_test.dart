import 'package:flutter_test/flutter_test.dart';

import '../support/a11y.dart';
import '../support/screen_nav.dart';

/// The automated accessibility-guideline harness, run over every top-level
/// surface (inventory: `test/support/screen_nav.dart`). Each test pumps a
/// surface in a realistic state and asserts, via `meetsGuideline`:
///
/// * `labeledTapTargetGuideline` — every operable control announces something
/// * `androidTapTargetGuideline` + `iOSTapTargetGuideline` — ≥ 48dp targets
/// * `textContrastGuideline` — rendered text clears WCAG AA against its
///   background
///
/// p5.1a locked in the label + tap-target guidelines (the audit found the UI
/// already met them). p5.1c adds the contrast assertion here: the systematic
/// both-theme proof lives in `theme_contrast_test.dart` (a pure sweep over the
/// `ColorScheme` role pairs); this on-screen check is the belt-and-braces that
/// the widgets actually paint those roles the way the token test assumes.
void main() {
  for (final surface in screenSurfaces) {
    testWidgets('${surface.name} — a11y guidelines', (tester) async {
      await surface.run(tester, (tester) => expectMeetsA11yGuidelines(tester));
    });
  }
}
