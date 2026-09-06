import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import 'birth_control_recalibration_screen.dart';
import 'mode_catalog.dart';
import 'modes_providers.dart';
import 'pcos_screen.dart';
import 'perimenopause_screen.dart';
import 'postpartum_screen.dart';
import 'pregnancy_week_screen.dart';
import 'ttc_screen.dart';

/// The "Modes" screen, reached from Settings → "Life-stage & condition modes"
/// (p7.1): every Phase 7 mode with a one-line description and an on/off control.
/// Each mode is off by default; turning one off only clears its flag — no
/// logged data is removed. The shared framework the rest of Phase 7 fills in.
class ModesPage extends StatelessWidget {
  const ModesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Modes')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Optional lenses for a life stage or condition. Each one is off '
              'until you turn it on, and turning it off keeps all your data. '
              'None of them change how you log day to day.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          for (final mode in LifeStageMode.values) _ModeTile(mode: mode),
        ],
      ),
    );
  }
}

/// The screen behind a mode's "Open" row. Only called for modes where
/// [modeHasScreen] is true.
Widget _modeScreen(LifeStageMode mode) => switch (mode) {
  LifeStageMode.pregnancy => const PregnancyWeekScreen(),
  LifeStageMode.ttc => const TtcScreen(),
  LifeStageMode.pcos => const PcosScreen(),
  LifeStageMode.perimenopause => const PerimenopauseScreen(),
  LifeStageMode.birthControlSwitch => const BirthControlRecalibrationScreen(),
  _ => const PostpartumScreen(),
};

class _ModeTile extends ConsumerWidget {
  const _ModeTile({required this.mode});

  final LifeStageMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = modeCatalogEntry(mode);
    final enabled =
        ref.watch(lifeStageModeEnabledProvider(mode)).valueOrNull ?? false;
    final canOpen = enabled && modeHasScreen(mode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: enabled,
          title: Text(entry.title),
          subtitle: Text(entry.description),
          isThreeLine: true,
          onChanged: (want) =>
              setLifeStageModeEnabled(ref, mode, enabled: want),
        ),
        // Modes with a screen (modeHasScreen): postpartum (p7.1), pregnancy
        // (p7.2a). Later slices add their screen to `_modeScreen` as it lands.
        if (canOpen)
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text('Open ${entry.title}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => _modeScreen(mode))),
          ),
      ],
    );
  }
}
