package com.olf.olf_app

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
class MainActivity : FlutterFragmentActivity() {
    private val screenSecurityChannel = "olf/screen_security"

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
    }
}
