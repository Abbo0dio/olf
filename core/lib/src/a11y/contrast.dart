/// WCAG 2.x relative-luminance and contrast-ratio maths.
///
/// Pure Dart — colours are 32-bit ARGB ints (`0xAARRGGBB`), the exact layout
/// Flutter's `Color` exposes via `toARGB32()`, so `core` stays Flutter-free.
/// The app-side theme-token contrast sweep (p5.1c) feeds `ColorScheme` roles
/// through [contrastRatio] / [meetsWcagAa]; the boundary constants and the
/// sRGB linearisation live here so they have their own pure unit tests.
library;

import 'dart:math' as math;

/// WCAG 2.x AA — minimum contrast for normal-size body text
/// (smaller than 18pt, or smaller than 14pt bold).
const double wcagAaNormalText = 4.5;

/// WCAG 2.x AA — minimum contrast for large text (18pt+, or 14pt+ bold) and
/// for user-interface components / graphical objects (SC 1.4.11 Non-text
/// Contrast).
const double wcagAaLargeTextOrComponent = 3.0;

int _red(int argb) => (argb >> 16) & 0xff;
int _green(int argb) => (argb >> 8) & 0xff;
int _blue(int argb) => argb & 0xff;
int _alpha(int argb) => (argb >> 24) & 0xff;

/// sRGB 8-bit channel → linear-light component, per the WCAG definition.
double _linearise(int channel) {
  final c = channel / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Relative luminance of an **opaque** sRGB colour: 0.0 (black) … 1.0 (white),
/// per WCAG 2.x. The alpha channel is ignored — composite a translucent colour
/// with [alphaComposite] first.
double relativeLuminance(int argb) =>
    0.2126 * _linearise(_red(argb)) +
    0.7152 * _linearise(_green(argb)) +
    0.0722 * _linearise(_blue(argb));

/// Contrast ratio between two **opaque** colours: 1.0 (identical) … 21.0
/// (black vs white). Order-independent.
double contrastRatio(int argb1, int argb2) {
  final l1 = relativeLuminance(argb1);
  final l2 = relativeLuminance(argb2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Composite a (possibly translucent) [foreground] over an **opaque**
/// [background], returning an opaque ARGB int. Straight (non-premultiplied)
/// alpha in sRGB space — the same result Flutter paints for one `Color` drawn
/// over another.
int alphaComposite(int foreground, int background) {
  final fa = _alpha(foreground) / 255.0;
  int mix(int f, int b) => ((f * fa) + (b * (1 - fa))).round().clamp(0, 255);
  return (0xff << 24) |
      (mix(_red(foreground), _red(background)) << 16) |
      (mix(_green(foreground), _green(background)) << 8) |
      mix(_blue(foreground), _blue(background));
}

/// Whether [ratio] clears the WCAG 2.x AA bar. [largeText] selects the 3:1
/// threshold used for large text and for non-text UI components; the default
/// is the 4.5:1 normal-text threshold.
bool meetsWcagAa(double ratio, {bool largeText = false}) =>
    ratio >= (largeText ? wcagAaLargeTextOrComponent : wcagAaNormalText);
