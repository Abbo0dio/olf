import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/theme/olf_theme.dart';
import 'package:olf_core/olf_core.dart';

/// p5.1c — WCAG 2.2 AA colour-contrast sweep over the actual olf theme, in
/// **both** brightnesses. The contrast maths is `core`'s
/// (`contrast.dart`, unit-tested in `core/test/a11y/`); this walks the real
/// `olfTheme(brightness).colorScheme` and asserts every foreground/background
/// role pair the app paints clears its bar:
///
/// * normal text  ≥ 4.5:1  (`wcagAaNormalText`)
/// * large text & non-text UI components  ≥ 3:1  (`wcagAaLargeTextOrComponent`)
///
/// A failing pair is fixed by adjusting the token in `olf_theme.dart`, never by
/// lowering the threshold or excluding the pair.
///
/// p1.12: the cycle-phase wheel's four arc colours (`primary`, `secondary`,
/// `tertiary`, `outline`, each on `surface`) are all checked here rather than
/// in a separate wheel-specific test — see `cycle_wheel.dart`.
void main() {
  int argb(Color c) => c.toARGB32();

  /// One foreground-on-background expectation.
  ({
    String label,
    Color Function(ColorScheme) fg,
    Color Function(ColorScheme) bg,
    bool large,
  })
  pair(
    String label,
    Color Function(ColorScheme) fg,
    Color Function(ColorScheme) bg, {
    bool large = false,
  }) => (label: label, fg: fg, bg: bg, large: large);

  // The role pairs olf actually renders. The M3 on*/​*container pairs are
  // content text (4.5:1); the accent-on-surface pairs are used both as button
  // labels (text, 4.5:1) and as icons / chart strokes, so the stricter 4.5 is
  // applied. `outline` on surface is the divider / border case (component, 3:1).
  final pairs =
      <
        ({
          String label,
          Color Function(ColorScheme) fg,
          Color Function(ColorScheme) bg,
          bool large,
        })
      >[
        pair('onSurface / surface', (s) => s.onSurface, (s) => s.surface),
        pair(
          'onSurfaceVariant / surface',
          (s) => s.onSurfaceVariant,
          (s) => s.surface,
        ),
        pair(
          'onSurfaceVariant / surfaceContainerLowest',
          (s) => s.onSurfaceVariant,
          (s) => s.surfaceContainerLowest,
        ),
        pair(
          'onSurfaceVariant / surfaceContainerLow',
          (s) => s.onSurfaceVariant,
          (s) => s.surfaceContainerLow,
        ),
        pair(
          'onSurfaceVariant / surfaceContainerHigh',
          (s) => s.onSurfaceVariant,
          (s) => s.surfaceContainerHigh,
        ),
        pair(
          'onSurfaceVariant / surfaceContainerHighest',
          (s) => s.onSurfaceVariant,
          (s) => s.surfaceContainerHighest,
        ),
        pair(
          'onSurface / surfaceContainerLow',
          (s) => s.onSurface,
          (s) => s.surfaceContainerLow,
        ),
        pair(
          'onSurface / surfaceContainerHighest',
          (s) => s.onSurface,
          (s) => s.surfaceContainerHighest,
        ),
        pair('onPrimary / primary', (s) => s.onPrimary, (s) => s.primary),
        pair(
          'onPrimaryContainer / primaryContainer',
          (s) => s.onPrimaryContainer,
          (s) => s.primaryContainer,
        ),
        pair(
          'onSecondary / secondary',
          (s) => s.onSecondary,
          (s) => s.secondary,
        ),
        pair(
          'onSecondaryContainer / secondaryContainer',
          (s) => s.onSecondaryContainer,
          (s) => s.secondaryContainer,
        ),
        pair('onTertiary / tertiary', (s) => s.onTertiary, (s) => s.tertiary),
        pair(
          'onTertiaryContainer / tertiaryContainer',
          (s) => s.onTertiaryContainer,
          (s) => s.tertiaryContainer,
        ),
        pair('onError / error', (s) => s.onError, (s) => s.error),
        pair(
          'onErrorContainer / errorContainer',
          (s) => s.onErrorContainer,
          (s) => s.errorContainer,
        ),
        pair(
          'onInverseSurface / inverseSurface',
          (s) => s.onInverseSurface,
          (s) => s.inverseSurface,
        ),
        // Accent colours used as text/icons directly on the scaffold surface.
        pair('primary / surface', (s) => s.primary, (s) => s.surface),
        pair('error / surface', (s) => s.error, (s) => s.surface),
        pair('tertiary / surface', (s) => s.tertiary, (s) => s.surface),
        // p1.12: also the cycle-wheel's follicular arc colour.
        pair('secondary / surface', (s) => s.secondary, (s) => s.surface),
        // Borders, dividers, unfilled outlines — non-text UI components.
        pair(
          'outline / surface',
          (s) => s.outline,
          (s) => s.surface,
          large: true,
        ),
      ];

  for (final brightness in Brightness.values) {
    final scheme = olfTheme(brightness).colorScheme;
    group('${brightness.name} theme', () {
      for (final p in pairs) {
        test('${p.label} — ${p.large ? '≥ 3:1' : '≥ 4.5:1'}', () {
          final ratio = contrastRatio(argb(p.fg(scheme)), argb(p.bg(scheme)));
          expect(
            meetsWcagAa(ratio, largeText: p.large),
            isTrue,
            reason:
                '${brightness.name}: ${p.label} is ${ratio.toStringAsFixed(2)}:1, '
                'below the ${p.large ? wcagAaLargeTextOrComponent : wcagAaNormalText}:1 bar '
                '— fix the token in olf_theme.dart',
          );
        });
      }
    });
  }
}
