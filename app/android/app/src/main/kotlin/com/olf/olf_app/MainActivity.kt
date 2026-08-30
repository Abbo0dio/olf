package com.olf.olf_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the local_auth
// plugin (p2.1) so the Android biometric prompt has a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
