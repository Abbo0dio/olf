import 'dart:io';

import 'package:test/test.dart';

/// Exercises `.github/scripts/dependency_audit.dart` end-to-end. This is the
/// "deliberately-failing fixture proves the gate blocks" requirement for p0.3.
///
/// `dart test` runs with the package directory (`core/`) as CWD, so the script
/// lives one level up and the fixtures sit beside this file.
void main() {
  final dart = Platform.resolvedExecutable;
  const script = '../.github/scripts/dependency_audit.dart';
  const fixtures = 'test/fixtures';

  ProcessResult run(List<String> args, {Map<String, String>? environment}) =>
      Process.runSync(
        dart,
        [script, ...args],
        environment: environment,
        includeParentEnvironment: true,
      );

  setUpAll(() {
    expect(
      File(script).existsSync(),
      isTrue,
      reason: 'audit script not found at $script (run from core/)',
    );
  });

  test('BLOCKS a lockfile containing denylisted packages', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--lock',
      '$fixtures/denylisted.pubspec.lock',
    ]);

    expect(r.exitCode, 1, reason: r.stderr.toString());
    expect(r.stderr, contains('firebase_analytics')); // exact rule
    expect(r.stderr, contains('appsflyer_sdk')); // ~substring rule
  });

  test('PASSES a lockfile with only innocuous packages', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--lock',
      '$fixtures/clean.pubspec.lock',
    ]);

    expect(r.exitCode, 0, reason: r.stderr.toString());
    expect(r.stdout, contains('PASS'));
  });

  test('BLOCKS an un-audited <uses-permission> in the manifest', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--manifest',
      '$fixtures/manifest_unaudited.xml',
    ]);

    expect(r.exitCode, 1, reason: r.stderr.toString());
    expect(r.stderr, contains('INTERNET'));
    expect(r.stderr, contains('un-audited permission'));
  });

  test('PASSES when the permission carries an "audited:" justification', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--manifest',
      '$fixtures/manifest_audited.xml',
    ]);

    expect(r.exitCode, 0, reason: r.stderr.toString());
  });

  test('BLOCKS an Android net-security config that re-enables cleartext', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--net-config',
      '$fixtures/net_config_cleartext.xml',
    ]);

    expect(r.exitCode, 1, reason: r.stderr.toString());
    expect(r.stderr, contains('cleartextTrafficPermitted="true"'));
  });

  test('PASSES the hardened Android net-security config', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--net-config',
      '$fixtures/net_config_strict.xml',
    ]);

    expect(r.exitCode, 0, reason: r.stderr.toString());
  });

  test('BLOCKS an iOS plist that allows arbitrary loads', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--plist',
      '$fixtures/plist_ats_weak.plist',
    ]);

    expect(r.exitCode, 1, reason: r.stderr.toString());
    expect(r.stderr, contains('NSAllowsArbitraryLoads'));
  });

  test('PASSES an iOS plist with strict App Transport Security', () {
    final r = run([
      '--denylist',
      '$fixtures/denylist.txt',
      '--plist',
      '$fixtures/plist_ats_strict.plist',
    ]);

    expect(r.exitCode, 0, reason: r.stderr.toString());
  });

  test('the real repo denylist + committed locks + transport config pass', () {
    final r = run([
      '--denylist',
      '../.github/dependency-denylist.txt',
      '--lock',
      'pubspec.lock',
      '--lock',
      '../app/pubspec.lock',
      '--manifest',
      '../app/android/app/src/main/AndroidManifest.xml',
      '--net-config',
      '../app/android/app/src/main/res/xml/network_security_config.xml',
      '--plist',
      '../app/ios/Runner/Info.plist',
    ]);

    expect(
      r.exitCode,
      0,
      reason: 'real tree tripped the audit:\n${r.stdout}\n${r.stderr}',
    );
  });

  test('exits 2 on a bad invocation, and says the gate did not run', () {
    final r = run(['--lock', '$fixtures/clean.pubspec.lock']);
    expect(r.exitCode, 2, reason: r.stderr.toString());
    expect(r.stderr, contains('the gate did not run'));
    expect(r.stderr, contains('This is still a failure'));
  });

  // --- p2.9: the gate is a strict, un-waivable release blocker ---------------

  group('release blocker (p2.9)', () {
    test(
      'failure output points at the escalation process, not an override',
      () {
        final r = run([
          '--denylist',
          '$fixtures/denylist.txt',
          '--lock',
          '$fixtures/denylisted.pubspec.lock',
        ]);
        expect(r.exitCode, 1);
        final err = r.stderr.toString();
        expect(err, contains('RELEASE BLOCKER'));
        expect(err, contains('cannot be waived'));
        expect(err, contains('no flag, no environment variable, and no'));
        expect(err, contains('REMOVE it'));
        expect(err, contains('security reviewer'));
        expect(err, contains('docs/dependency-audit.md'));
        expect(err, contains('docs/release-checklist.md'));
      },
    );

    test('no environment variable can turn the gate off', () {
      // Anything a well-meaning "just this once" hack might reach for.
      for (final key in const [
        'SKIP_DEPENDENCY_AUDIT',
        'OLF_SKIP_AUDIT',
        'DEPENDENCY_AUDIT_SKIP',
        'CI_SKIP_AUDIT',
        'NO_AUDIT',
        'DEPENDENCY_AUDIT_ALLOW',
      ]) {
        final r = run(
          [
            '--denylist',
            '$fixtures/denylist.txt',
            '--lock',
            '$fixtures/denylisted.pubspec.lock',
          ],
          environment: {key: '1'},
        );
        expect(
          r.exitCode,
          1,
          reason: '$key must not suppress a violation\n${r.stderr}',
        );
      }
    });

    test('the script exposes no skip/allow/force flag', () {
      final src = File(script).readAsStringSync();
      for (final needle in const [
        "'--skip'",
        "'--force'",
        "'--allow'",
        "'--allowlist'",
        "'--no-fail'",
        "'--waive'",
      ]) {
        expect(
          src,
          isNot(contains(needle)),
          reason: 'audit script must not grow a $needle bypass',
        );
      }
    });

    test('CI wiring keeps the gate strict and complete', () {
      final ci = File('../.github/workflows/ci.yml').readAsStringSync();

      // The audit runs with the full argument set (weakening any of these
      // would shrink what the gate sees).
      for (final arg in const [
        '--denylist .github/dependency-denylist.txt',
        '--lock core/pubspec.lock',
        '--lock app/pubspec.lock',
        '--manifest app/android/app/src/main/AndroidManifest.xml',
        '--net-config app/android/app/src/main/res/xml/network_security_config.xml',
        '--plist app/ios/Runner/Info.plist',
      ]) {
        expect(ci, contains(arg), reason: 'ci.yml lost audit arg: $arg');
      }

      // The stale-lock guard stays in place.
      expect(
        ci,
        contains('git diff --exit-code core/pubspec.lock app/pubspec.lock'),
      );

      // No soft-pass on the audit job.
      expect(
        ci,
        isNot(contains('continue-on-error')),
        reason:
            'no job may be marked continue-on-error while the audit is a blocker',
      );

      // ci-ok depends on the audit and requires it to actually succeed
      // (a skip is treated as a failure).
      final ciOk = ci.substring(ci.indexOf('ci-ok:'));
      expect(ciOk, contains('dependency-audit'));
      expect(ciOk, contains('"dependency-audit".result'));
      expect(ciOk, contains(r'if [ "$audit_result" != "success" ]'));
    });
  });
}
