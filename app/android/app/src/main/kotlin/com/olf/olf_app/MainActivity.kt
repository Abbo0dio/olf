package com.olf.olf_app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by the local_auth
// plugin (p2.1) so the Android biometric prompt has a FragmentActivity host.
//
// p2.4 adds the `olf/screen_security` MethodChannel: `setSecure(true)` sets
// WindowManager FLAG_SECURE, which keeps the window out of screenshots, screen
// recordings and the Recents thumbnail; `setSecure(false)` clears it. Driven by
// PrivacyShield for the app's lifetime. Kept here rather than as a Flutter
// plugin because it is a couple of lines of window management.
//
// p5.4 adds the `olf/app_icon` MethodChannel: `setIcon("branded" | "notes")`
// enables the matching `<activity-alias>` launcher entry and disables the
// others via PackageManager. Android stops the app once the last enabled
// launcher component changes, so the Flutter side warns the user first.
class MainActivity : FlutterFragmentActivity() {
    private val screenSecurityChannel = "olf/screen_security"
    private val appIconChannel = "olf/app_icon"

    // Alias component names must match `AndroidManifest.xml` and
    // `AppIconOption.androidAlias` in the Dart layer.
    private val iconAliases = mapOf(
        "branded" to "com.olf.olf_app.MainActivityBranded",
        "notes" to "com.olf.olf_app.MainActivityNotes",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenSecurityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.arguments as? Boolean ?: true
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appIconChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val id = call.arguments as? String
                    val target = iconAliases[id]
                    if (target == null) {
                        result.error("bad_arg", "unknown icon id: $id", null)
                        return@setMethodCallHandler
                    }
                    try {
                        applyIconAlias(target)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("switch_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // Enable `enabledComponent` and disable every other alias in `iconAliases`.
    // DONT_KILL_APP keeps this process alive long enough to return a result;
    // Android still tears the task down shortly after.
    private fun applyIconAlias(enabledComponent: String) {
        val pm = packageManager
        for (component in iconAliases.values) {
            val state = if (component == enabledComponent) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                ComponentName(packageName, component),
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
