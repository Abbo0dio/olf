import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olf_core/olf_core.dart';

import '../providers.dart';
import '../settings/settings_providers.dart';

/// "Reduce spoken detail" (p5.3), live from `app_settings`. `false` until the
/// database is open or the user turns it on — full detail is spoken by default.
///
/// When `true`, sensitive `Semantics` labels collapse to a generic form (an
/// entry *exists*, not what it is) so a screen reader on a shared device does
/// not broadcast health state. The visible UI never changes.
final reduceSpokenDetailProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db is! AsyncData) return Stream<bool>.value(false);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.reduceSpokenDetail)
      .map((value) => value == 'true');
});

/// Turn "Reduce spoken detail" on or off.
Future<void> setReduceSpokenDetail(WidgetRef ref, {required bool value}) => ref
    .read(settingsRepositoryProvider)
    .set(SettingKeys.reduceSpokenDetail, value ? 'true' : 'false');

/// The single seam every sensitive `Semantics`/`semanticsLabel` call site goes
/// through: the [redacted] string when "Reduce spoken detail" is on, otherwise
/// [full]. Keeping it one function means the redaction policy — and the list of
/// what counts as sensitive — stays auditable in one place.
String spokenDetail(
  bool reduce, {
  required String full,
  required String redacted,
}) => reduce ? redacted : full;

/// `semanticsLabel`-shaped variant: `null` (use the widget's own text) when not
/// reducing, the [redacted] string when reducing. For `Text(..., semanticsLabel:
/// spokenLabel(reduce, redacted: '…'))` — the visible text is untouched.
String? spokenLabel(bool reduce, {required String redacted}) =>
    reduce ? redacted : null;
