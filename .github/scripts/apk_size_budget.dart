// APK size budget — a hard gate (p5.5).
//
// Enforces the install-size half of requirements.md §3 ("install size kept
// small; track it in CI"): the release APK must not grow past a committed
// baseline by more than a set percentage.
//
//   dart .github/scripts/apk_size_budget.dart \
//     --apk app/build/app/outputs/flutter-apk/app-release.apk \
//     --baseline .github/perf-baseline.json
//
// Reads `apk_release_bytes` and `apk_growth_threshold_pct` from the baseline
// JSON and fails if the measured APK exceeds `apk_release_bytes * (1 +
// pct/100)`. A measured size well *below* the baseline is not a failure, but
// prints a reminder to lower the baseline in its own commit.
//
// `--update` rewrites `apk_release_bytes` in the baseline file to the measured
// value (and leaves everything else untouched) — the deliberate, visible way to
// move the baseline. Never run in CI; it is for the human doing the bump.
//
// Pure `dart:` libraries, so it runs with no `pub get`. Exit code 0 = within
// budget, 1 = over budget, 2 = bad invocation / missing input. A non-zero exit
// fails the CI `perf-budget` job, which is part of the `CI OK` aggregate.
//
// See docs/performance-budget.md.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  String? apkPath;
  String? baselinePath;
  var update = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() {
      if (i + 1 >= args.length) _fail2('missing value for $a');
      return args[++i];
    }

    switch (a) {
      case '--apk':
        apkPath = next();
      case '--baseline':
        baselinePath = next();
      case '--update':
        update = true;
      case '-h':
      case '--help':
        stdout.writeln(
          'usage: apk_size_budget.dart --apk F --baseline F [--update]',
        );
        exit(0);
      default:
        _fail2('unknown argument: $a');
    }
  }

  if (apkPath == null || baselinePath == null) {
    _fail2('both --apk and --baseline are required');
  }

  final apk = File(apkPath);
  if (!apk.existsSync()) _fail2('APK not found: $apkPath');
  final measured = apk.lengthSync();

  final baselineFile = File(baselinePath);
  if (!baselineFile.existsSync()) _fail2('baseline not found: $baselinePath');

  final Map<String, dynamic> baseline;
  try {
    baseline =
        jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (e) {
    _fail2('baseline is not valid JSON: $e');
  }

  final baseBytes = (baseline['apk_release_bytes'] as num?)?.toInt();
  final pct = (baseline['apk_growth_threshold_pct'] as num?)?.toDouble();
  if (baseBytes == null || pct == null) {
    _fail2('baseline is missing apk_release_bytes or apk_growth_threshold_pct');
  }

  if (update) {
    baseline['apk_release_bytes'] = measured;
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(baseline)}\n',
    );
    stdout.writeln(
      'baseline apk_release_bytes updated: $baseBytes -> $measured '
      '(${_mib(measured)} MiB)',
    );
    exit(0);
  }

  final ceiling = (baseBytes * (1 + pct / 100)).floor();
  final deltaPct = (measured - baseBytes) / baseBytes * 100;

  final summary = StringBuffer()
    ..writeln('### APK size budget (§3)')
    ..writeln()
    ..writeln('| | bytes | MiB |')
    ..writeln('|---|---:|---:|')
    ..writeln(
      '| measured (`app-release.apk`) | $measured | ${_mib(measured)} |',
    )
    ..writeln('| baseline | $baseBytes | ${_mib(baseBytes)} |')
    ..writeln(
      '| ceiling (baseline + ${pct.toStringAsFixed(0)}%) | $ceiling | '
      '${_mib(ceiling)} |',
    )
    ..writeln()
    ..writeln(
      'measured is ${deltaPct >= 0 ? '+' : ''}'
      '${deltaPct.toStringAsFixed(2)}% vs baseline.',
    );

  _writeStepSummary(summary.toString());
  stdout.write(summary);

  if (measured > ceiling) {
    stderr.writeln(
      '::error::release APK is ${_mib(measured)} MiB '
      '(${deltaPct.toStringAsFixed(2)}% over the ${_mib(baseBytes)} MiB '
      'baseline; ceiling ${_mib(ceiling)} MiB). Either trim the growth or, if '
      'it is genuinely justified, bump .github/perf-baseline.json in its own '
      'commit with the reason in the PR (see docs/performance-budget.md).',
    );
    exit(1);
  }

  if (deltaPct <= -pct) {
    stdout.writeln(
      '::notice::release APK shrank to ${deltaPct.toStringAsFixed(2)}% below '
      'the baseline — consider lowering apk_release_bytes in '
      '.github/perf-baseline.json so the budget keeps its bite.',
    );
  }

  stdout.writeln('APK size within budget.');
  exit(0);
}

String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

void _writeStepSummary(String markdown) {
  final path = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (path == null || path.isEmpty) return;
  try {
    File(path).writeAsStringSync('$markdown\n', mode: FileMode.append);
  } catch (_) {
    // Best-effort only — never fail the gate over a summary write.
  }
}

Never _fail2(String message) {
  stderr.writeln('apk_size_budget: $message');
  exit(2);
}
