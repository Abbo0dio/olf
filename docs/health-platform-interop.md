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

olf syncs **menstrual flow** and **basal body temperature** read + write on both
platforms, plus **wrist temperature read-only on iOS** (p8.1a). The asymmetry
below is recorded for whoever wires a further type later; p8.2 adds a per-reading
device tag on top of these (see "Device attribution" below).

| Data type | Apple HealthKit | Android Health Connect | olf status |
|---|---|---|---|
| Menstrual flow | `HKCategoryTypeIdentifier.menstrualFlow` (read + write) | `MenstruationFlowRecord` (read + write) | **wired** (p6.2 / p6.3) |
| Basal body temperature | `HKQuantityTypeIdentifier.basalBodyTemperature` (read + write) | `BasalBodyTemperatureRecord` (read + write) | **wired** (p6.2 / p6.3) |
| Body temperature | `HKQuantityTypeIdentifier.bodyTemperature` (read + write) | `BodyTemperatureRecord` (read + write) | declared in the `core` interface; not bridged |
| Wrist / skin temperature | wrist temperature is **sleeping-wear only and read-only** (`HKQuantityTypeIdentifier.appleSleepingWristTemperature`, iOS 16+) | `SkinTemperatureRecord` — general-purpose **read + write** | **wired read-only on iOS** (p8.1a — passive Apple Watch overnight capture, re-typed to `basalBodyTemperature` at the reconcile boundary and stored tagged `sleepingWrist`); **not bridged on Android**. The platforms are **not** symmetric — an Android build could write skin temperature, an iOS build cannot write wrist temperature at all |
| Sleep | `HKCategoryTypeIdentifier.sleepAnalysis` (read + write) | `SleepSessionRecord` (read + write) | declared in the `core` interface; not bridged (HRV + sleep mapping is p8.5) |

For the still-unbridged types the gateway returns an empty read and a no-op
write with a logged note, on both platforms, so the shared `ImportReconciler`
and Settings widget stay symmetric.

## Device attribution (p8.2)

A user whose Oura Ring, Garmin watch or similar already syncs temperature / flow
into Apple Health or Health Connect can see that data in olf **labelled by
device** — through this same bridge, with **no vendor SDK, OAuth, network call
or new permission**. Each imported reading carries a free-form `source_device`
tag (schema v11 — nullable `source_device` TEXT on `daily_flows` and
`bbt_entries`).

Where the tag comes from is **asymmetric**, the same way the capability table
above is:

| | Apple HealthKit | Android Health Connect |
|---|---|---|
| Source of the tag | `HKSample.sourceRevision.source.name` (the writing app / integration — "Oura", "Garmin Connect"), falling back to `HKSample.device?.name` (`HKDevice`, usually `nil` for third-party data synced through Health) | `Record.metadata.dataOrigin.packageName` (e.g. `com.ouraring.oura`) |
| Shape | already human-readable | a reverse-DNS package id |
| Often missing? | `HKDevice` frequently `nil`; the source name is the reliable field | present whenever another app wrote the record; empty for direct user entry |

olf stores the raw string verbatim and **prettifies only at the edge**
(`app/lib/src/health/device_label.dart`: known package prefixes —
`com.ouraring.*` → "Oura", `com.garmin.*` → "Garmin", … — an unknown package id
falls back to its last dotted segment, a plain iOS name passes through). The
prefix table lives in `core/lib/src/health/known_devices.dart` since p8.6, shared
with the precedence classifier so the two never drift. The tag is **provenance
only** — never a query or matching key, and an in-app edit clears it (mirroring
`source` → `manual`).

Two readings for the same day that materially disagree and share a precedence
tier (see below) become a `ConflictReason.crossDeviceDisagreement` on the
conflict-review screen. Values that agree collapse to one reading; a device
revising its own earlier reading is a plain update. Single-source behaviour is
byte-for-byte unchanged. The "Apps & export" section grows a per-device status
list (device label, reading count, last-seen; `reduceSpokenDetail`-redacted;
shown only when at least one tagged row exists — no per-device connect control).

HRV and sleep mapping stay **out of scope until p8.5**; Garmin's server-to-server
Health API and Oura's cloud API are **not** used — the platform path is the
supported route (Oura cloud API is p8.3).

## Multi-source precedence (p8.6)

When a single `(type, day)` slot has readings from several places — a typed
value, an Apple-Watch sleeping-wrist temperature, an Oura temperature, a bare
platform sample — olf resolves to **one value per day** with a fixed, documented
order. The policy is pure `core`
(`core/lib/src/health/source_precedence.dart`), consulted inside the existing
`ImportReconciler` decision point; **nothing new is persisted** and the resolver
function is never stored.

### The classifier

Every reading is sorted into one **tier** from exactly what olf already stores —
the `source` enum, the p8.1a `measurement_kind`, and the p8.2 `source_device`
tag:

| Rank | Tier | A reading lands here when… |
|---|---|---|
| 3 | `manual` | `source == manual` — the user typed it. |
| 2 | `attributedDevice` | automatic, **not** sleeping-wrist, and `source_device` resolves to a vendor olf recognises (`core/lib/src/health/known_devices.dart` — the same table `device_label.dart` prettifies with: `com.ouraring.*` / "Oura", `com.garmin.*` / "Garmin", "Garmin Connect", Withings, Fitbit, WHOOP, Polar, Wahoo, Samsung Health, plus Google Fit / Health Connect package ids). |
| 1 | `sleepingWrist` | `measurement_kind == sleepingWrist` (a passive Apple-Watch overnight reading, p8.1a) — regardless of the `source_device` string. |
| 0 | `genericPlatform` | automatic, not sleeping-wrist, and `source_device` is absent or names nothing recognised — a bare platform sample. |

A `source_device` that only prettifies via the *fallback* (`com.acme.ringapp` →
"Ringapp", an unknown plain name passing through) is **not** an attributed
device — `isAttributedDevice` requires an exact table hit.

### How the reconciler uses it

- **`manual` is never auto-resolved.** A disagreement with a typed value is
  always a `manualDisagreement` conflict, whatever the automatic sources are.
- **A clear rank winner among automatic sources auto-resolves** — the
  higher-tier reading becomes a deterministic `ReconciliationUpdate` (or insert);
  the lower-tier reading is dropped from olf's plan as a `ReconciliationSupersede`
  (not surfaced, not counted in the sync summary).
- **A same-tier disagreement between two different recognised devices stays a
  `crossDeviceDisagreement`** for the user. Three or more same-tier sources for
  one day fold into a **single** conflict carrying the extras in
  `ReconciliationConflict.alsoContending`, so the review screen shows every value
  at once with a per-source "Use this reading" action alongside keep-mine /
  dismiss. No bulk actions.
- Fully order-independent: the same inputs in any order produce the same plan.

### No data loss, and the v1 limitation

Every raw reading is retained **in the OS health store**; olf keeps only the
resolved per-day value (a derived read) in `bbt_entries` / `daily_flows`, which
retention (p2.3) and encrypted backup already cover. Deleting the winning
source's stored row lets the next sync re-run the policy and the runner-up win.

**Limitation:** because olf does not persist the losing readings, changing the
precedence order later does **not** retroactively re-resolve past days — that
needs a fresh pull from the platform. The v1 order is fixed, so this only
matters if a later slice makes the order user-configurable (backlog); a
`raw_health_readings` table was considered for p8.6 and deferred.

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
