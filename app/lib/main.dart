import 'package:flutter/material.dart';

// olf_core (the pure-Dart domain layer) is a dependency of this package; the
// first screen to actually consume it is the "Day N" readout in p0.4.

void main() => runApp(const OlfApp());

/// Root of the olf app.
///
/// p0.2 scope: an empty, themed home screen that renders correctly in light and
/// dark. Real theming (neutral, non-gendered palette + pronoun setting) is p1.9;
/// the first real feature (log a period) is p0.4.
class OlfApp extends StatelessWidget {
  const OlfApp({super.key});

  // Provisional neutral seed — deliberately not pink/gendered. p1.9 owns the
  // real design-token baseline.
  static const Color _seed = Color(0xFF4C6B5A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'olf',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Placeholder home screen. Nothing is logged yet — p0.4 adds the first action.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('olf')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing logged yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
