import 'package:flutter_test/flutter_test.dart';

import '../support/a11y.dart';
import '../support/screen_nav.dart';

/// p5.1a — the automated accessibility-guideline harness run over every
/// top-level surface (inventory: `test/support/screen_nav.dart`). Each test
/// pumps a surface in a realistic state and asserts [labeledTapTargetGuideline]
/// (every operable control announces something) plus the Android + iOS
/// minimum-tap-target-size guidelines — the p5.1a audit found the existing UI
/// already meets all three, so they are locked in here rather than deferred.
///
/// The one deferral is `contrast: false` → **p5.1c**, which owns the systematic
/// WCAG contrast sweep across *both* themes (a pure test over the theme tokens);
/// `textContrastGuideline` here would only check the one brightness a given test
/// happens to pump. Text-scaling reflow is **p5.1b** (`text_scaling_test.dart`).
void main() {
  for (final surface in screenSurfaces) {
    testWidgets('${surface.name} — a11y guidelines', (tester) async {
      await surface.run(
        tester,
        // p5.1c: WCAG contrast sweep across both themes is p5.1c's job.
        (tester) => expectMeetsA11yGuidelines(tester, contrast: false),
      );
    });
  }
}
