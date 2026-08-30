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

  ProcessResult run(List<String> args) =>
      Process.runSync(dart, [script, ...args]);

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

  test('exits 2 on a bad invocation (no --denylist)', () {
    final r = run(['--lock', '$fixtures/clean.pubspec.lock']);
    expect(r.exitCode, 2, reason: r.stderr.toString());
  });
}
