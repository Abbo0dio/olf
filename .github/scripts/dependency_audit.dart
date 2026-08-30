// Dependency audit — the real gate (p0.3).
//
// Enforces these rules from requirements.md §3 / §8 and DEVELOPMENT_PLAN.md §1.4:
//
//   1. No dependency — direct OR transitive — whose package name matches the
//      committed denylist of advertising / analytics / tracking SDKs.
//   2. No `<uses-permission>` in the app's MAIN Android manifest without an
//      adjacent `audited:` justification comment, and no
//      `android:usesCleartextTraffic="true"` there.
//   3. Transport security baseline (p2.6): every Android network-security config
//      keeps `cleartextTrafficPermitted="false"` with no cleartext re-enable
//      and no `<debug-overrides>`, and every iOS Info.plist keeps App Transport
//      Security strict — `NSAllowsArbitraryLoads*` / `NSAllowsLocalNetworking`
//      never `<true/>`, and no `NSExceptionDomains`.
//
// Pure `dart:` libraries only, so it runs as a plain script with no `pub get`:
//
//   dart .github/scripts/dependency_audit.dart \
//     --denylist .github/dependency-denylist.txt \
//     --lock core/pubspec.lock --lock app/pubspec.lock \
//     --manifest app/android/app/src/main/AndroidManifest.xml \
//     --net-config app/android/app/src/main/res/xml/network_security_config.xml \
//     --plist app/ios/Runner/Info.plist
//
// Exit code 0 = clean, 1 = violation(s), 2 = bad invocation / missing input.
//
// Extending the denylist: docs/dependency-audit.md.

import 'dart:io';

void main(List<String> args) {
  final denylistPaths = <String>[];
  final lockPaths = <String>[];
  final manifestPaths = <String>[];
  final netConfigPaths = <String>[];
  final plistPaths = <String>[];

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() {
      if (i + 1 >= args.length) _fail2('missing value for $a');
      return args[++i];
    }

    switch (a) {
      case '--denylist':
        denylistPaths.add(next());
      case '--lock':
        lockPaths.add(next());
      case '--manifest':
        manifestPaths.add(next());
      case '--net-config':
        netConfigPaths.add(next());
      case '--plist':
        plistPaths.add(next());
      case '-h':
      case '--help':
        stdout.writeln(
          'usage: dependency_audit.dart --denylist F '
          '[--lock F ...] [--manifest F ...] [--net-config F ...] '
          '[--plist F ...]',
        );
        exit(0);
      default:
        _fail2('unknown argument: $a');
    }
  }

  if (denylistPaths.isEmpty) _fail2('at least one --denylist is required');
  if (lockPaths.isEmpty &&
      manifestPaths.isEmpty &&
      netConfigPaths.isEmpty &&
      plistPaths.isEmpty) {
    _fail2(
      'nothing to check: pass --lock, --manifest, --net-config or --plist',
    );
  }

  final rules = <_DenyRule>[];
  for (final p in denylistPaths) {
    rules.addAll(_parseDenylist(_read(p)));
  }
  if (rules.isEmpty) _fail2('denylist(s) parsed to zero rules');

  final violations = <String>[];

  // Rule 1 — denylisted packages anywhere in the locked graph.
  for (final lockPath in lockPaths) {
    final pkgs = _parseLockPackages(_read(lockPath));
    if (pkgs.isEmpty) _fail2('no packages parsed from $lockPath');
    for (final entry in pkgs.entries) {
      for (final rule in rules) {
        if (rule.matches(entry.key)) {
          violations.add(
            'denylisted dependency "${entry.key}" '
            '(${entry.value}) in $lockPath — matched ${rule.describe()}',
          );
        }
      }
    }
    stdout.writeln('scanned $lockPath: ${pkgs.length} packages');
  }

  // Rule 2 — un-audited permissions / cleartext in the main manifest.
  for (final manifestPath in manifestPaths) {
    violations.addAll(_auditManifest(manifestPath));
    stdout.writeln('scanned $manifestPath');
  }

  // Rule 3a — Android network-security config stays cleartext-free (p2.6).
  for (final netConfigPath in netConfigPaths) {
    violations.addAll(_auditNetConfig(netConfigPath));
    stdout.writeln('scanned $netConfigPath');
  }

  // Rule 3b — iOS App Transport Security stays strict (p2.6).
  for (final plistPath in plistPaths) {
    violations.addAll(_auditPlist(plistPath));
    stdout.writeln('scanned $plistPath');
  }

  if (violations.isEmpty) {
    stdout.writeln('dependency audit: PASS (${rules.length} denylist rules)');
    exit(0);
  }

  stderr.writeln(
    '\ndependency audit: FAIL — ${violations.length} violation(s):',
  );
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln('\nSee docs/dependency-audit.md.');
  exit(1);
}

Never _fail2(String msg) {
  stderr.writeln('dependency audit: $msg');
  exit(2);
}

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) _fail2('file not found: $path');
  return f.readAsStringSync();
}

/// XML / plist comments carry prose that can mention the very tokens the
/// transport checks look for ("do not set cleartext…="true"") — scan only the
/// live markup.
String _stripXmlComments(String text) =>
    text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// A single denylist rule. Three forms:
///   name          exact package-name match
///   ~fragment     case-insensitive substring match
///   re:pattern    case-insensitive regular-expression match
class _DenyRule {
  _DenyRule.exact(this._value) : _kind = _Kind.exact, _re = null;
  _DenyRule.substring(this._value) : _kind = _Kind.substring, _re = null;
  _DenyRule.regex(this._value)
    : _kind = _Kind.regex,
      _re = RegExp(_value, caseSensitive: false);

  final _Kind _kind;
  final String _value;
  final RegExp? _re;

  bool matches(String pkg) => switch (_kind) {
    _Kind.exact => pkg == _value,
    _Kind.substring => pkg.toLowerCase().contains(_value.toLowerCase()),
    _Kind.regex => _re!.hasMatch(pkg),
  };

  String describe() => switch (_kind) {
    _Kind.exact => 'exact "$_value"',
    _Kind.substring => 'substring "~$_value"',
    _Kind.regex => 'regex "re:$_value"',
  };
}

enum _Kind { exact, substring, regex }

List<_DenyRule> _parseDenylist(String text) {
  final rules = <_DenyRule>[];
  for (var line in text.split('\n')) {
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash);
    line = line.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('re:')) {
      rules.add(_DenyRule.regex(line.substring(3).trim()));
    } else if (line.startsWith('~')) {
      rules.add(_DenyRule.substring(line.substring(1).trim()));
    } else {
      rules.add(_DenyRule.exact(line));
    }
  }
  return rules;
}

/// Maps every package in a `pubspec.lock` to its dependency kind
/// ("direct main", "direct dev", "transitive").
Map<String, String> _parseLockPackages(String text) {
  final result = <String, String>{};
  final lines = text.split('\n');
  var inPackages = false;
  String? current;
  for (final line in lines) {
    if (!inPackages) {
      if (line.trimRight() == 'packages:') inPackages = true;
      continue;
    }
    // A top-level key ends the packages block (e.g. "sdks:").
    if (line.isNotEmpty && line[0] != ' ' && line.trim().isNotEmpty) break;

    final pkg = RegExp(r'^  ([A-Za-z_][A-Za-z0-9_]*):\s*$').firstMatch(line);
    if (pkg != null) {
      current = pkg.group(1);
      result[current!] = 'unknown';
      continue;
    }
    if (current != null) {
      final dep = RegExp(
        r'^\s+dependency:\s*"?([^"]+?)"?\s*$',
      ).firstMatch(line);
      if (dep != null) result[current] = dep.group(1)!;
    }
  }
  return result;
}

/// Flags every `<uses-permission>` whose declaration is not preceded, within a
/// few lines, by an `audited:` justification comment, plus any
/// `android:usesCleartextTraffic="true"` (p2.6).
List<String> _auditManifest(String path) {
  final text = _read(path);
  final lines = text.split('\n');
  final out = <String>[];

  if (RegExp(
    'usesCleartextTraffic\\s*=\\s*"true"',
    caseSensitive: false,
  ).hasMatch(_stripXmlComments(text))) {
    out.add(
      'android:usesCleartextTraffic="true" in $path — the transport baseline '
      '(p2.6) is TLS-only; remove it or set it "false"',
    );
  }

  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(
      r'<uses-permission[^>]*android:name="([^"]+)"',
    ).firstMatch(lines[i]);
    if (m == null) continue;
    final permission = m.group(1)!;
    final windowStart = (i - 4).clamp(0, lines.length);
    final context = lines.sublist(windowStart, i + 1).join('\n');
    if (!context.contains('audited:')) {
      out.add(
        'un-audited permission "$permission" in $path:${i + 1} — add a '
        '"<!-- audited: <reason> -->" comment immediately above it',
      );
    }
  }
  return out;
}

/// Android network-security config (p2.6): must declare
/// `cleartextTrafficPermitted="false"`, must never say `"true"`, and must carry
/// no `<debug-overrides>` (which can silently re-trust user CAs / cleartext).
List<String> _auditNetConfig(String path) {
  final text = _stripXmlComments(_read(path));
  final out = <String>[];
  if (RegExp(
    'cleartextTrafficPermitted\\s*=\\s*"true"',
    caseSensitive: false,
  ).hasMatch(text)) {
    out.add(
      'cleartextTrafficPermitted="true" in $path — the transport baseline '
      '(p2.6) is TLS-only',
    );
  }
  if (!RegExp(
    'cleartextTrafficPermitted\\s*=\\s*"false"',
    caseSensitive: false,
  ).hasMatch(text)) {
    out.add(
      'no cleartextTrafficPermitted="false" in $path — the transport baseline '
      '(p2.6) must state it explicitly',
    );
  }
  if (text.contains('<debug-overrides')) {
    out.add(
      '<debug-overrides> in $path — not allowed in the committed config (it '
      'can re-trust user CAs / cleartext)',
    );
  }
  return out;
}

/// iOS Info.plist (p2.6): App Transport Security must stay strict — no
/// `NSAllowsArbitraryLoads*` / `NSAllowsLocalNetworking` set to `<true/>`, and
/// no `NSExceptionDomains` dictionary.
List<String> _auditPlist(String path) {
  final text = _stripXmlComments(_read(path));
  final out = <String>[];
  const atsTrueKeys = <String>[
    'NSAllowsArbitraryLoads',
    'NSAllowsArbitraryLoadsInWebContent',
    'NSAllowsArbitraryLoadsForMedia',
    'NSAllowsLocalNetworking',
  ];
  for (final key in atsTrueKeys) {
    // `<key>NAME</key>` followed (any whitespace) by `<true/>`.
    final re = RegExp('<key>\\s*$key\\s*</key>\\s*<true\\s*/>');
    if (re.hasMatch(text)) {
      out.add(
        '$key is <true/> in $path — App Transport Security must stay strict '
        '(p2.6)',
      );
    }
  }
  if (RegExp(r'<key>\s*NSExceptionDomains\s*</key>').hasMatch(text)) {
    out.add(
      'NSExceptionDomains present in $path — no per-domain ATS exceptions are '
      'allowed at the baseline (p2.6)',
    );
  }
  return out;
}
