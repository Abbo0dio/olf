# Health-platform interop (Phase 6)

How olf talks to the OS health stores — Apple Health on iOS (p6.2) and Android
Health Connect (p6.3) — and where the two platforms differ.

The bridge is **opt-in and default-off**. It is one Settings tile, "Connect a
health app", under **Apps & export**. Nothing crosses the boundary until the
user turns it on and grants the OS permission sheet; it is revocable in-app and,
fully, in the platform's own health settings. See
[`threat-model.md`](threat-model.md) trust boundary #8.

## One channel, two native peers

Both platforms sit behind the `core` `HealthPlatformGateway` interface and share
**one** hand-rolled `MethodChannel`, `olf/health`, with an identical wire
contract:

| | iOS (p6.2) | Android (p6.3) |
|---|---|---|
| Gateway | `HealthKitGateway` | `HealthConnectGateway` |
| Native peer | `HealthKitBridge` (Swift, `AppDelegate.swift`) | `MainActivity.kt` Health Connect bridge (Kotlin) |
| OS API | Apple HealthKit (`HKHealthStore`) | `androidx.health.connect:connect-client` (Gradle dep, **not** a pub package) |
| Dependency cost | none — HealthKit ships in the iOS SDK | one AndroidX Gradle dep; `pubspec.lock` untouched |
| Build floor | unchanged | `minSdk` 24 → 26 (`connect-client` needs API 26+; olf already documents "Android 8+ / API 26+" as its minimum, so this only aligns the actual config) |
| Availability | always (`isAvailable == true` on every supported iPhone) | runtime probe — Health Connect is an installable system app; `HealthConnectClient.getSdkStatus(...) == SDK_AVAILABLE`. Not installed / needs update → the tile is hidden |

The Dart side — the channel wrapper, the pure codec (`health_channel.dart`,
`flow_mapping.dart`), `HealthImportService`, and the Settings widget — is **the
same code on both platforms**. Only the native peer differs.

### Menstrual-flow scale translation

The shared Dart codec speaks the HealthKit `HKCategoryValueMenstrualFlow` scale.
Health Connect's `MenstruationFlowRecord.flow` uses a different set of integers,
so the **Kotlin bridge** translates in both directions; the Dart codec never
changes:

| Health Connect | HealthKit wire | olf `FlowIntensity` |
|---|---|---|
| `FLOW_UNKNOWN` = 0 | `unspecified` = 1 | `spotting` |
| `FLOW_LIGHT` = 1 | `light` = 2 | `light` |
| `FLOW_MEDIUM` = 2 | `medium` = 3 | `medium` |
| `FLOW_HEAVY` = 3 | `heavy` = 4 | `heavy` |
| — | `none` = 5 | dropped on read; skipped on write |

## No Google Fit — by design

The legacy **Google Fit APIs shut down in 2026** (the Fit REST API and the
Android Fit SDK / `com.google.android.gms.fitness`). olf does **not** integrate
Google Fit and never did. On Android the **only** supported health-data path is
**Health Connect**, Google's first-party on-device store reached over local IPC
through `androidx.health.connect:connect-client`. There is no cloud API, no
account, and no network call in this path — consistent with olf's local-only
posture.

## iOS vs Android capability asymmetry

olf syncs exactly **two** data types on both platforms today — menstrual flow
and basal body temperature — so the asymmetry below does not bite yet. It is
recorded here for whoever wires a third type later.

| Data type | Apple HealthKit | Android Health Connect | olf status |
|---|---|---|---|
| Menstrual flow | `HKCategoryTypeIdentifier.menstrualFlow` (read + write) | `MenstruationFlowRecord` (read + write) | **wired** (p6.2 / p6.3) |
| Basal body temperature | `HKQuantityTypeIdentifier.basalBodyTemperature` (read + write) | `BasalBodyTemperatureRecord` (read + write) | **wired** (p6.2 / p6.3) |
| Body temperature | `HKQuantityTypeIdentifier.bodyTemperature` (read + write) | `BodyTemperatureRecord` (read + write) | declared in the `core` interface; not bridged |
| Wrist / skin temperature | wrist temperature is **sleeping-wear only and read-only** (`HKQuantityTypeIdentifier.appleSleepingWristTemperature`) | `SkinTemperatureRecord` — general-purpose **read + write** | declared in the `core` interface; not bridged. The platforms are **not** symmetric here — an Android build could write skin temperature, an iOS build cannot write wrist temperature at all |
| Sleep | `HKCategoryTypeIdentifier.sleepAnalysis` (read + write) | `SleepSessionRecord` (read + write) | declared in the `core` interface; not bridged |

For the three unbridged types the gateway returns an empty read and a no-op
write with a logged note, on both platforms, so the shared `ImportReconciler`
and Settings widget stay symmetric.

## Android permission set (p6.3)

The Android manifest declares **exactly four** Health Connect permissions, one
read + one write for each wired type, each with an `audited:` justification the
dependency-audit gate checks:

- `android.permission.health.READ_MENSTRUATION`
- `android.permission.health.WRITE_MENSTRUATION`
- `android.permission.health.READ_BASAL_BODY_TEMPERATURE`
- `android.permission.health.WRITE_BASAL_BODY_TEMPERATURE`

Plus, not permissions:

- an `<intent-filter>` for
  `androidx.health.connect.action.SHOW_PERMISSIONS_RATIONALE` on `.MainActivity`
  so Health Connect can deep-link back to olf's rationale;
- `<queries><package android:name="com.google.android.apps.healthdata" /></queries>`
  for Android 11+ package visibility, so `getSdkStatus` can see the provider.

Any change to this set is a dependency-audit permission-diff and must be
explained in the PR that makes it.
