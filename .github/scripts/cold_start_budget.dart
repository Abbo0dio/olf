// Cold-start budget — informational only (p5.5).
//
// Parses the `start_up_info.json` that `flutter run --trace-startup` writes and
// reports the engine-enter -> first-frame-rasterized time against the
// `cold_start_ceiling_ms` in the perf baseline.
//
//   dart .github/scripts/cold_start_budget.dart \
//     --trace app/build/start_up_info.json \
//     --baseline .github/perf-baseline.json
//
// This NEVER exits non-zero. Cold start is measured on a shared-runner
// emulator, which is too noisy to gate a merge on (see the refinement in
// DEVELOPMENT_PLAN.md p5.5). It runs in the nightly integration workflow, is
// wrapped in `continue-on-error`, and only emits a `::warning::` when the
// measured time is over the documented emulator-adjusted ceiling.
//
// Pure `dart:` libraries — runs with no `pub get`. See docs/performance-budget.md.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? tracePath;
  String? baselinePath;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() {
      if (i + 1 >= args.length) _bail('missing value for $a');
      return args[++i];
    }

    switch (a) {
      case '--trace':
        tracePath = next();
      case '--baseline':
        baselinePath = next();
      case '-h':
      case '--help':
        stdout.writeln('usage: cold_start_budget.dart --trace F --baseline F');
        return;
      default:
        _bail('unknown argument: $a (ignored)');
    }
  }

  if (tracePath == null || baselinePath == null) {
    _bail('both --trace and --baseline are required');
    return;
  }

  final traceFile = File(tracePath);
  if (!traceFile.existsSync()) {
    _bail(
      'no trace at $tracePath — flutter run --trace-startup produced '
      'nothing (emulator likely too slow/flaky this run)',
    );
    return;
  }

  int? micros;
  try {
    final trace =
        jsonDecode(traceFile.readAsStringSync()) as Map<String, dynamic>;
    // Prefer the rasterized-first-frame delta; fall back to the framework one.
    micros =
        (trace['timeToFirstFrameRasterizedMicros'] as num?)?.toInt() ??
        (trace['timeToFirstFrameMicros'] as num?)?.toInt();
  } on FormatException catch (e) {
    _bail('trace is not valid JSON: $e');
    return;
  }

  if (micros == null) {
    _bail('trace has no timeToFirstFrame*Micros field');
    return;
  }

  final ms = micros / 1000.0;

  int? ceilingMs;
  final baselineFile = File(baselinePath);
  if (baselineFile.existsSync()) {
    try {
      final baseline =
          jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
      ceilingMs = (baseline['cold_start_ceiling_ms'] as num?)?.toInt();
    } on FormatException {
      // fall through with a null ceiling
    }
  }

  final line = ceilingMs == null
      ? 'cold start (first frame rasterized): ${ms.toStringAsFixed(0)} ms'
      : 'cold start (first frame rasterized): ${ms.toStringAsFixed(0)} ms '
            '(emulator ceiling $ceilingMs ms)';
  stdout.writeln(line);
  _writeStepSummary('### Cold start (informational)\n\n$line\n');

  if (ceilingMs != null && ms > ceilingMs) {
    stdout.writeln(
      '::warning::cold start ${ms.toStringAsFixed(0)} ms exceeded the '
      '$ceilingMs ms emulator ceiling. This does not block merges — '
      'investigate a startup regression, or widen the documented ceiling in '
      '.github/perf-baseline.json if the runner got slower.',
    );
  }
  // Always a clean exit.
}

void _writeStepSummary(String markdown) {
  final path = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (path == null || path.isEmpty) return;
  try {
    File(path).writeAsStringSync('$markdown\n', mode: FileMode.append);
  } catch (_) {
    // best-effort
  }
}

void _bail(String message) {
  stdout.writeln('::warning::cold_start_budget: $message (non-blocking)');
}
