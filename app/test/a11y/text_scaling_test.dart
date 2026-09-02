import 'package:flutter_test/flutter_test.dart';

import '../support/screen_nav.dart';
import '../support/text_scaling.dart';

/// p5.1b — every top-level surface (inventory: `test/support/screen_nav.dart`,
/// shared with the p5.1a a11y sweep) must stay un-clipped at the OS's largest
/// text setting. This pumps each surface at text scale 1.0 / 1.5 / 2.0 and
/// asserts no `RenderFlex` overflow and no layout `FlutterError`.
///
/// Fixes for anything this flags are real reflow in `lib/` — intrinsic sizes,
/// `Wrap` / `Flexible`, scrollable sheets — never a clamped-down `textScaler`.
void main() {
  for (final surface in screenSurfaces) {
    for (final scale in textScales) {
      testWidgets('${surface.name} @ ${scale}x text — no overflow', (
        tester,
      ) async {
        useTextScale(tester, scale);
        await surface.run(
          tester,
          (tester) async =>
              expectNoOverflow(tester, where: '${surface.name} @ ${scale}x'),
        );
      });
    }
  }
}
