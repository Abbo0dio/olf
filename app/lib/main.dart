import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/home_page.dart';

void main() => runApp(const ProviderScope(child: OlfApp()));

/// Root of the olf app.
///
/// Real theming (neutral, non-gendered palette + pronoun setting) is p1.9.
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
