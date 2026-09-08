import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meds/meds_page.dart';
import 'patterns/patterns_view.dart';
import 'period/period_calendar_page.dart';
import 'pregnancy/pregnancy_events_page.dart';
import 'settings/settings_page.dart';

/// Which shell tab is showing. Ephemeral — session-only, no persistence (r3a).
/// 0 = Home, 1 = Calendar, 2 = Patterns.
final appTabIndexProvider = StateProvider<int>((ref) => 0);

/// The app shell (r3a): a 3-destination [NavigationBar] — Home · Calendar ·
/// Patterns — with Settings as a top-right gear (a utility, not a destination).
/// The Calendar tab's AppBar also carries an overflow menu for the demoted
/// Medications and Pregnancy-loss/birth screens.
///
/// The three tab bodies live in an [IndexedStack] so each keeps its scroll
/// position (and controller state) when you switch away and back.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _titles = ['olf', 'Calendar', 'Patterns'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(appTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
        actions: [
          if (index == 1)
            PopupMenuButton<_CalendarMenuAction>(
              tooltip: 'More',
              onSelected: (action) {
                final page = switch (action) {
                  _CalendarMenuAction.medications => const MedsPage(),
                  _CalendarMenuAction.pregnancyEvents =>
                    const PregnancyEventsPage(),
                };
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _CalendarMenuAction.medications,
                  child: Text('Medications'),
                ),
                PopupMenuItem(
                  value: _CalendarMenuAction.pregnancyEvents,
                  child: Text('Pregnancy loss & birth'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [
          PeriodCalendarView(variant: HomeVariant.home),
          PeriodCalendarView(variant: HomeVariant.calendar),
          PatternsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(appTabIndexProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Patterns',
          ),
        ],
      ),
    );
  }
}

enum _CalendarMenuAction { medications, pregnancyEvents }
