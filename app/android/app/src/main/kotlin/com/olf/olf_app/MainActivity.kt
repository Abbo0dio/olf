package com.olf.olf_app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.view.WindowManager
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BasalBodyTemperatureRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Temperature
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.reflect.KClass

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
//
// p6.3 adds the Android half of the `olf/health` MethodChannel — a hand-rolled
// bridge to Android Health Connect, mirroring the Swift `HealthKitBridge`
// (p6.2) method-for-method and speaking the identical wire contract. Only two
// data types cross: menstrual flow and basal body temperature. The Kotlin side
// translates Health Connect's menstrual-flow scale
// (FLOW_UNKNOWN=0 / LIGHT=1 / MEDIUM=2 / HEAVY=3) to and from the HealthKit
// wire scale the shared Dart codec speaks (unspecified=1 / light=2 / medium=3 /
// heavy=4 / none=5), so the Dart layer is reused unchanged. Local IPC only —
// nothing here touches the network.
class MainActivity : FlutterFragmentActivity() {
    private val screenSecurityChannel = "olf/screen_security"
    private val appIconChannel = "olf/app_icon"
    private val healthChannel = "olf/health"

    // Alias component names must match `AndroidManifest.xml` and
    // `AppIconOption.androidAlias` in the Dart layer.
    private val iconAliases = mapOf(
        "branded" to "com.olf.olf_app.MainActivityBranded",
        "notes" to "com.olf.olf_app.MainActivityNotes",
    )

    // --- p6.3 Health Connect bridge state ------------------------------------

    // Background scope for the suspend Health Connect calls; replies marshalled
    // back with runOnUiThread. SupervisorJob so one failed call can't cancel the
    // scope. Dispatchers.Default only (coroutines-core) — no reliance on
    // kotlinx-coroutines-android's Main dispatcher.
    private val healthScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var healthConnectClient: HealthConnectClient? = null

    // A permission request is a round trip through an Activity result; hold the
    // pending Flutter result and the set that was asked for until it returns.
    private var pendingHealthAuth: MethodChannel.Result? = null
    private var pendingHealthAuthWanted: Set<String> = emptySet()

    private val requestHealthPermissions: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { granted ->
            val result = pendingHealthAuth
            val wanted = pendingHealthAuthWanted
            pendingHealthAuth = null
            pendingHealthAuthWanted = emptySet()
            result?.success(if (granted.containsAll(wanted)) "granted" else "denied")
        }

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            healthChannel,
        ).setMethodCallHandler { call, result -> handleHealth(call, result) }
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

    // --- p6.3 Health Connect bridge ----------------------------------------------

    /** Wire tokens (the `core` HealthSampleType enum names) → Health Connect record types. */
    private fun recordTypeForToken(token: String): KClass<out Record>? = when (token) {
        "menstrualFlow" -> MenstruationFlowRecord::class
        "basalBodyTemperature" -> BasalBodyTemperatureRecord::class
        else -> null
    }

    /** Health Connect is an installable system app — it may be absent or need a provider update. */
    private fun healthConnectAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE

    private fun healthClient(): HealthConnectClient {
        val existing = healthConnectClient
        if (existing != null) return existing
        val created = HealthConnectClient.getOrCreate(this)
        healthConnectClient = created
        return created
    }

    /**
     * The read/write permission strings implied by a `{types, access}` request.
     * For the two wired types + `readWrite` this is exactly the four
     * `android.permission.health.*` entries declared in AndroidManifest.xml.
     */
    private fun permissionsFor(call: MethodCall): Set<String> {
        val tokens = call.argument<List<String>>("types").orEmpty()
        val access = call.argument<String>("access") ?: "readWrite"
        val wantRead = access == "read" || access == "readWrite"
        val wantWrite = access == "write" || access == "readWrite"
        val out = mutableSetOf<String>()
        for (token in tokens) {
            val type = recordTypeForToken(token) ?: continue
            if (wantRead) out.add(HealthPermission.getReadPermission(type))
            if (wantWrite) out.add(HealthPermission.getWritePermission(type))
        }
        return out
    }

    private fun handleHealth(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(healthConnectAvailable())
            "requestAuthorization" -> requestHealthAuthorization(call, result)
            "authorizationStatus" -> healthAuthorizationStatus(call, result)
            "read" -> healthRead(call, result)
            "write" -> healthWrite(call, result)
            "delete" -> healthDelete(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestHealthAuthorization(call: MethodCall, result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.error("unavailable", "Health Connect is not available on this device.", null)
            return
        }
        val wanted = permissionsFor(call)
        if (wanted.isEmpty()) {
            result.success("denied")
            return
        }
        healthScope.launch {
            try {
                val granted = healthClient().permissionController.getGrantedPermissions()
                runOnUiThread {
                    when {
                        granted.containsAll(wanted) -> result.success("granted")
                        pendingHealthAuth != null ->
                            result.error("busy", "A permission request is already in progress.", null)
                        else -> {
                            pendingHealthAuth = result
                            pendingHealthAuthWanted = wanted
                            requestHealthPermissions.launch(wanted)
                        }
                    }
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("auth_failed", e.message, null) }
            }
        }
    }

    private fun healthAuthorizationStatus(call: MethodCall, result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.success("notDetermined")
            return
        }
        val wanted = permissionsFor(call)
        if (wanted.isEmpty()) {
            result.success("denied")
            return
        }
        healthScope.launch {
            try {
                val granted = healthClient().permissionController.getGrantedPermissions()
                val status = if (granted.containsAll(wanted)) "granted" else "notDetermined"
                runOnUiThread { result.success(status) }
            } catch (e: Exception) {
                runOnUiThread { result.error("status_failed", e.message, null) }
            }
        }
    }

    private fun healthRead(call: MethodCall, result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.error("unavailable", "Health Connect is not available on this device.", null)
            return
        }
        val tokens = call.argument<List<String>>("types").orEmpty()
        val fromMs = call.argument<Number>("fromMs")?.toLong()
        val toMs = call.argument<Number>("toMs")?.toLong()
        if (fromMs == null || toMs == null) {
            result.error("bad_arg", "read needs fromMs/toMs", null)
            return
        }
        val range = TimeRangeFilter.between(Instant.ofEpochMilli(fromMs), Instant.ofEpochMilli(toMs))
        healthScope.launch {
            try {
                val client = healthClient()
                val rows = ArrayList<Map<String, Any?>>()
                for (token in tokens) {
                    when (token) {
                        "menstrualFlow" -> {
                            val response = client.readRecords(
                                ReadRecordsRequest(
                                    recordType = MenstruationFlowRecord::class,
                                    timeRangeFilter = range,
                                ),
                            )
                            for (record in response.records) {
                                val at = record.time.toEpochMilli()
                                rows.add(
                                    mapOf(
                                        "type" to "menstrualFlow",
                                        "startMs" to at,
                                        "endMs" to at,
                                        "value" to hcFlowToWire(record.flow).toDouble(),
                                        "externalId" to record.metadata.id.ifEmpty { null },
                                    ),
                                )
                            }
                        }
                        "basalBodyTemperature" -> {
                            val response = client.readRecords(
                                ReadRecordsRequest(
                                    recordType = BasalBodyTemperatureRecord::class,
                                    timeRangeFilter = range,
                                ),
                            )
                            for (record in response.records) {
                                val at = record.time.toEpochMilli()
                                rows.add(
                                    mapOf(
                                        "type" to "basalBodyTemperature",
                                        "startMs" to at,
                                        "endMs" to at,
                                        "value" to record.temperature.inCelsius,
                                        "externalId" to record.metadata.id.ifEmpty { null },
                                    ),
                                )
                            }
                        }
                        else -> {
                            // An unmapped type — the Dart side never sends one, but stay quiet.
                        }
                    }
                }
                runOnUiThread { result.success(rows) }
            } catch (e: Exception) {
                runOnUiThread { result.error("read_failed", e.message, null) }
            }
        }
    }

    private fun healthWrite(call: MethodCall, result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.error("unavailable", "Health Connect is not available on this device.", null)
            return
        }
        val samples = call.argument<List<Map<String, Any?>>>("samples").orEmpty()
        val records = ArrayList<Record>()
        for (sample in samples) {
            val token = sample["type"] as? String ?: continue
            val startMs = (sample["startMs"] as? Number)?.toLong() ?: continue
            val value = (sample["value"] as? Number)?.toDouble() ?: continue
            val time = Instant.ofEpochMilli(startMs)
            when (token) {
                "menstrualFlow" -> {
                    val flow = wireFlowToHc(value.toInt()) ?: continue
                    records.add(
                        MenstruationFlowRecord(
                            time = time,
                            zoneOffset = null,
                            flow = flow,
                            metadata = Metadata.manualEntry(),
                        ),
                    )
                }
                "basalBodyTemperature" -> {
                    records.add(
                        BasalBodyTemperatureRecord(
                            time = time,
                            zoneOffset = null,
                            temperature = Temperature.celsius(value),
                            metadata = Metadata.manualEntry(),
                        ),
                    )
                }
                else -> {
                    // Unmapped type — silent no-op, matches the Dart write contract.
                }
            }
        }
        if (records.isEmpty()) {
            result.success(null)
            return
        }
        healthScope.launch {
            try {
                healthClient().insertRecords(records)
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("write_failed", e.message, null) }
            }
        }
    }

    private fun healthDelete(call: MethodCall, result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.success(null)
            return
        }
        val type = call.argument<String>("type")?.let { recordTypeForToken(it) }
        val fromMs = call.argument<Number>("fromMs")?.toLong()
        val toMs = call.argument<Number>("toMs")?.toLong()
        if (type == null || fromMs == null || toMs == null) {
            result.success(null) // unmapped type / bad args → no-op, matches iOS
            return
        }
        val range = TimeRangeFilter.between(Instant.ofEpochMilli(fromMs), Instant.ofEpochMilli(toMs))
        healthScope.launch {
            try {
                healthClient().deleteRecords(type, range)
                runOnUiThread { result.success(null) }
            } catch (e: Exception) {
                runOnUiThread { result.error("delete_failed", e.message, null) }
            }
        }
    }

    // Health Connect's menstrual-flow scale ↔ the HealthKit wire scale the shared
    // Dart codec (`flow_mapping.dart`) speaks. The Dart side is identical for both
    // platforms; this is the whole of the Android-specific translation.
    //
    //   Health Connect            HealthKit wire      olf FlowIntensity
    //   FLOW_UNKNOWN = 0     <-->  unspecified = 1  →  spotting
    //   FLOW_LIGHT   = 1     <-->  light       = 2  →  light
    //   FLOW_MEDIUM  = 2     <-->  medium      = 3  →  medium
    //   FLOW_HEAVY   = 3     <-->  heavy       = 4  →  heavy
    //   (no equivalent)           none        = 5  →  (dropped on read; skipped on write)

    private fun hcFlowToWire(hcFlow: Int): Int = when (hcFlow) {
        MenstruationFlowRecord.FLOW_LIGHT -> WIRE_FLOW_LIGHT
        MenstruationFlowRecord.FLOW_MEDIUM -> WIRE_FLOW_MEDIUM
        MenstruationFlowRecord.FLOW_HEAVY -> WIRE_FLOW_HEAVY
        else -> WIRE_FLOW_UNSPECIFIED
    }

    private fun wireFlowToHc(wireFlow: Int): Int? = when (wireFlow) {
        WIRE_FLOW_UNSPECIFIED -> MenstruationFlowRecord.FLOW_UNKNOWN
        WIRE_FLOW_LIGHT -> MenstruationFlowRecord.FLOW_LIGHT
        WIRE_FLOW_MEDIUM -> MenstruationFlowRecord.FLOW_MEDIUM
        WIRE_FLOW_HEAVY -> MenstruationFlowRecord.FLOW_HEAVY
        else -> null // WIRE_FLOW_NONE / anything unexpected → nothing to write
    }

    private companion object {
        const val WIRE_FLOW_UNSPECIFIED = 1
        const val WIRE_FLOW_LIGHT = 2
        const val WIRE_FLOW_MEDIUM = 3
        const val WIRE_FLOW_HEAVY = 4
    }
}
