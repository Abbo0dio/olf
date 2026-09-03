import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The home-screen presence options (p5.4).
///
/// Exactly two: the normal branded olf icon, and one deliberately plain,
/// unlabelled alternative so the app is less obvious at a glance on a shared or
/// observed device. This is a discreet-presence affordance, not a theme — it
/// changes the launcher icon and name, nothing in-app.
enum AppIconOption {
  /// The normal olf icon and name. The default with nothing stored.
  branded(
    id: 'branded',
    label: 'Default',
    androidAlias: 'com.olf.olf_app.MainActivityBranded',
    // `null` = the primary icon in the asset catalog (iOS resets to it when
    // `setAlternateIconName` is passed `nil`).
    iosAlternateName: null,
  ),

  /// A plain grey "notes page" glyph, labelled "Notes". No cycle or health
  /// imagery and the word "olf" appears nowhere.
  notes(
    id: 'notes',
    label: 'Notes',
    androidAlias: 'com.olf.olf_app.MainActivityNotes',
    iosAlternateName: 'AppIconNotes',
  );

  const AppIconOption({
    required this.id,
    required this.label,
    required this.androidAlias,
    required this.iosAlternateName,
  });

  /// Stable token persisted in `app_settings` (`SettingKeys.appIcon`).
  final String id;

  /// Short name for the Settings picker.
  final String label;

  /// Fully-qualified `activity-alias` component name in `AndroidManifest.xml`.
  /// The native handler enables exactly this one and disables the others.
  final String androidAlias;

  /// Name of the `CFBundleAlternateIcons` entry, or `null` for the primary
  /// icon.
  final String? iosAlternateName;

  /// Parse a stored token. Anything unrecognised → [AppIconOption.branded].
  static AppIconOption fromStorage(String? value) {
    for (final option in AppIconOption.values) {
      if (option.id == value) return option;
    }
    return AppIconOption.branded;
  }
}

/// Raised by [AppIconRepository.apply] when the platform icon switch did not
/// take effect. The caller must leave the stored preference untouched and show
/// a calm, non-alarming message.
class AppIconException implements Exception {
  const AppIconException(this.message);
  final String message;

  @override
  String toString() => 'AppIconException: $message';
}

/// Seam over the platform "change the launcher icon" capability (p5.4).
///
/// Same shape as [ScreenSecurity] (p2.4) and [BiometricGateway] (p2.1): the app
/// depends on this interface, the production impl wraps a hand-rolled method
/// channel, and tests inject a fake so CI never touches a channel.
///
/// Unlike [ScreenSecurity], [apply] **does** surface failure — the point of the
/// feature is that the user knows whether their icon actually changed.
abstract interface class AppIconRepository {
  /// Switch the active launcher icon to [option]. Returns normally once the
  /// platform reports success; throws [AppIconException] on any failure or when
  /// the platform has no alternate-icon support.
  Future<void> apply(AppIconOption option);
}

/// Production [AppIconRepository] over the `olf/app_icon` method channel,
/// handled natively in `MainActivity.kt` (Android `activity-alias` toggling)
/// and `AppDelegate.swift` (`UIApplication.setAlternateIconName`).
class MethodChannelAppIconRepository implements AppIconRepository {
  const MethodChannelAppIconRepository();

  static const MethodChannel _channel = MethodChannel('olf/app_icon');

  @override
  Future<void> apply(AppIconOption option) async {
    try {
      await _channel.invokeMethod<void>('setIcon', option.id);
    } on MissingPluginException {
      // Desktop / web / the test binding: no launcher to reskin.
      throw const AppIconException(
        'Changing the app icon is not supported here.',
      );
    } on PlatformException catch (e) {
      debugPrint('app_icon: setIcon(${option.id}) failed: ${e.code}');
      throw const AppIconException(
        "Couldn't change the app icon. The current icon is unchanged.",
      );
    }
  }
}

/// The seam. Overridden with a fake in tests.
final appIconRepositoryProvider = Provider<AppIconRepository>(
  (ref) => const MethodChannelAppIconRepository(),
);
