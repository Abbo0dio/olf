import 'package:flutter_test/flutter_test.dart';

import '../support/a11y.dart';
import '../support/screen_nav.dart';

/// p5.1a — a screen reader must never land on an operable control with nothing
/// to announce. For every top-level surface (inventory:
/// `test/support/screen_nav.dart`) this walks the live semantics tree and fails
/// if any node with a tap / long-press action has an empty
/// label + value + tooltip. Complements the `meetsGuideline` sweep in
/// `screen_guidelines_test.dart` (which only checks nodes Flutter tags as tap
/// targets); this catches bare `GestureDetector` / `InkWell` nodes too.
void main() {
  for (final surface in screenSurfaces) {
    testWidgets('${surface.name} — every tappable is labelled', (tester) async {
      await surface.run(tester, (tester) async {
        final offenders = unlabelledTappables(tester);
        expect(
          offenders,
          isEmpty,
          reason:
              'operable semantics nodes with no announcement:\n'
              '${offenders.join('\n')}',
        );
      });
    });
  }
}
