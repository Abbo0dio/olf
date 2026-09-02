import 'package:olf_core/olf_core.dart';
import 'package:test/test.dart';

/// Pure-maths unit tests for the WCAG contrast helper. The app-side sweep in
/// `app/test/a11y/theme_contrast_test.dart` trusts these numbers, so pin them
/// against values from the WCAG 2.x definition and the well-known boundary
/// greys.
void main() {
  const black = 0xFF000000;
  const white = 0xFFFFFFFF;

  group('relativeLuminance', () {
    test('black is 0.0, white is 1.0', () {
      expect(relativeLuminance(black), 0.0);
      expect(relativeLuminance(white), closeTo(1.0, 1e-9));
    });

    test('ignores the alpha channel', () {
      expect(
        relativeLuminance(0x00FFFFFF),
        closeTo(relativeLuminance(white), 1e-12),
      );
    });

    test('mid grey sits well below the midpoint (sRGB is not linear)', () {
      // #808080 → ~0.2158, not 0.5.
      expect(relativeLuminance(0xFF808080), closeTo(0.2159, 1e-3));
    });
  });

  group('contrastRatio', () {
    test('black on white is the maximum 21:1', () {
      expect(contrastRatio(black, white), closeTo(21.0, 1e-6));
    });

    test('a colour against itself is 1:1', () {
      expect(contrastRatio(0xFF4C6B5A, 0xFF4C6B5A), closeTo(1.0, 1e-9));
    });

    test('is order-independent', () {
      expect(
        contrastRatio(0xFF123456, 0xFFEEDDCC),
        closeTo(contrastRatio(0xFFEEDDCC, 0xFF123456), 1e-12),
      );
    });

    test('#767676 on white is the canonical 4.5:1 boundary (just passes)', () {
      final ratio = contrastRatio(0xFF767676, white);
      expect(ratio, closeTo(4.54, 0.02));
      expect(meetsWcagAa(ratio), isTrue);
    });

    test('#777777 on white just fails the 4.5:1 normal-text bar', () {
      final ratio = contrastRatio(0xFF777777, white);
      expect(ratio, closeTo(4.48, 0.02));
      expect(meetsWcagAa(ratio), isFalse);
      // …but clears the 3:1 large-text / component bar.
      expect(meetsWcagAa(ratio, largeText: true), isTrue);
    });

    test('#949494 on white is the 3:1 large-text boundary', () {
      final ratio = contrastRatio(0xFF949494, white);
      expect(ratio, closeTo(3.0, 0.05));
    });
  });

  group('meetsWcagAa', () {
    test('uses 4.5 for normal text and 3.0 for large text / components', () {
      expect(meetsWcagAa(4.5), isTrue);
      expect(meetsWcagAa(4.49), isFalse);
      expect(meetsWcagAa(3.0, largeText: true), isTrue);
      expect(meetsWcagAa(2.99, largeText: true), isFalse);
    });
  });

  group('alphaComposite', () {
    test('opaque foreground is returned unchanged (alpha forced to 0xFF)', () {
      expect(alphaComposite(0xFF3A5F4C, 0xFFFFFFFF), 0xFF3A5F4C);
    });

    test('fully transparent foreground yields the opaque background', () {
      expect(alphaComposite(0x00123456, 0xFF204030), 0xFF204030);
    });

    test('50% black over white is mid grey', () {
      // 0x80 = 128/255 ≈ 0.502 → 255 * (1 - 0.502) ≈ 127 per channel.
      final composited = alphaComposite(0x80000000, white);
      expect(composited, 0xFF7F7F7F);
    });

    test('lets a faded token be scored against what is actually painted', () {
      // The calendar flow-bar "empty" segment: 25%-alpha primary over surface.
      final faded = alphaComposite(0x40000000, white);
      final ratio = contrastRatio(faded, white);
      // 25% black over white → ~#BFBFBF, a low-contrast track (as intended).
      expect(ratio, lessThan(2.0));
    });
  });
}
