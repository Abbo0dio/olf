# Performance budget (p5.5)

Turns the `requirements.md` §3 performance line from prose into measured,
enforced numbers:

> iOS 15+, Android 8+ (API 26+). Cold start < 2 s on a 2019 mid-range Android;
> log-a-period flow ≤ 2 taps and < 100 ms feedback; install size kept small
> (track it in CI).

Three budgets, each with a fixed number, a measurement, and a deliberate way to
move the baseline.

| Budget | Number | Where it's enforced | Blocking? |
|---|---|---|---|
| Install size | release APK ≤ baseline + 5 % | `perf-budget` job in `ci.yml` | **yes** — part of `CI OK` |
| Log-a-period taps | home → logged period in ≤ 2 taps, ack within a tight pump budget | `app/test/perf/log_period_tap_budget_test.dart` in the `test` job | **yes** — part of `CI OK` |
| Cold start | first frame rasterized ≤ 2500 ms (emulator-adjusted) | nightly `nightly-integration.yml` | **no** — informational, never blocks a merge |

The split is an orchestrator decision (p5.5 row): the size and tap-count checks
are fast and deterministic, so they gate. Cold start can only be measured on a
shared-runner emulator, which is too noisy to gate a merge on — the same reason
`nightly-integration.yml` is deliberately not a required check.

## Install size

**Number.** The release APK must not exceed
`apk_release_bytes × (1 + apk_growth_threshold_pct / 100)` from
[`.github/perf-baseline.json`](../.github/perf-baseline.json). Threshold is
**5 %**.

**Baseline.** `apk_release_bytes` is the size of the last *signed release* APK —
seeded from `v1.0.1` (69 904 869 bytes ≈ 66.7 MiB, tag on `1ca0264`). It is a
real shipped number, not an aspiration.

**Measurement.** The `perf-budget` job runs `flutter build apk --release` (with
no keystore it falls back to debug *signing* but still produces a
release-optimised `app-release.apk`; the signature block is a few KB, so the
size is representative) and runs:

```
dart .github/scripts/apk_size_budget.dart \
  --apk app/build/app/outputs/flutter-apk/app-release.apk \
  --baseline .github/perf-baseline.json
```

Exit 1 (fails the job, fails `CI OK`) when the APK is over the ceiling. The job
also writes a size table to the run summary every time, pass or fail. If the APK
drops more than the threshold *below* the baseline, the script prints a
`::notice::` asking you to lower the baseline so the budget keeps its bite — it
does not fail.

**Moving the baseline.** Deliberate, visible, one commit of its own:

```
dart .github/scripts/apk_size_budget.dart \
  --apk app/build/app/outputs/flutter-apk/app-release.apk \
  --baseline .github/perf-baseline.json --update
```

That rewrites only `apk_release_bytes`. Commit it on its own with the reason in
the PR body (e.g. "adds sqlite FTS, +1.2 MiB, needed for search"). A baseline
bump that is not explained in its PR is a review stop.

## Log-a-period taps

**Number.** From the home/calendar screen, a period is logged in **≤ 2 taps**:
`Add a period` → `Save` (the editor is pre-filled with today, so no date entry).
The "Period saved." confirmation must be on screen within a 100 ms pump budget —
no long settle.

**Measurement.** `app/test/perf/log_period_tap_budget_test.dart`, a headless
widget test in the normal `test` job. It counts the taps and asserts the
acknowledgement appears after `pump()` + `pump(100 ms)` only.

**Moving it.** You don't. If a redesign genuinely needs a third tap, that is a
`requirements.md` §3 / §1 change — argue it in the PR and update this doc and
the test together.

## Cold start

**Number.** `requirements.md` §3 wants **< 2000 ms** cold start on a *2019
mid-range physical Android*. CI has no such device; it measures on an x86_64
emulator on a shared GitHub runner, which is slower and varies run to run. The
documented **emulator-adjusted ceiling is 2500 ms** (`cold_start_ceiling_ms` in
the baseline). Treat the physical-device target as the real bar — verified by
hand at release time (see the p0.5 device smoke table) — and the emulator number
as a regression tripwire only.

**Measurement.** The `android-emulator` job in `nightly-integration.yml`, after
the integration tests, runs `flutter run --profile --trace-startup` (killed by
`timeout` once the trace is written), then:

```
dart .github/scripts/cold_start_budget.dart \
  --trace app/build/start_up_info.json \
  --baseline .github/perf-baseline.json
```

`cold_start_budget.dart` parses `timeToFirstFrameRasterizedMicros`, logs it to
the run summary, and emits a `::warning::` if it is over the ceiling. It **never
exits non-zero**, and the step is wrapped in `continue-on-error: true` — a slow
or missing measurement can't turn the nightly run red, let alone block a merge.

**Moving the ceiling.** Edit `cold_start_ceiling_ms` in the baseline with a note
saying why (runner image got slower, etc.). Since nothing gates on it, this is
low-stakes — but keep the note honest so the number stays meaningful.

## At release time

The [release checklist](release-checklist.md) references the size baseline: the
size gate must be green on the release commit, and any baseline bump since the
last release must have its own explained commit.
