import 'package:flutter/material.dart';

/// The olf visual baseline (p1.9).
///
/// Deliberately neutral and discreet (`requirements.md` §4 / §9(7)): a muted
/// sage seed — not pink, not gendered — Material 3, and a shared component
/// baseline so light and dark are the same design in two brightnesses rather
/// than two different-looking apps.

/// Seed colour for both brightnesses. Carried over from the provisional theme.
const Color olfSeed = Color(0xFF4C6B5A);

/// The [ThemeData] for [brightness]. Used for `MaterialApp.theme` /
/// `.darkTheme`, and directly in the both-theme render tests.
ThemeData olfTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: olfSeed,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // Flat, quiet surfaces — nothing shouts.
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
