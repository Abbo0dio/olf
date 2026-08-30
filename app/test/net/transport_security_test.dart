import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olf_app/src/net/olf_http_client.dart';

/// Transport-security baseline (p2.6). Nothing calls the network yet; these
/// tests lock the seam's guarantees and prove no other file can bypass it.
void main() {
  group('OlfHttpClient seam', () {
    test('requireHttpsUrl passes https and rejects everything else', () {
      final ok = Uri.parse('https://example.test/x');
      expect(requireHttpsUrl(ok), same(ok));

      for (final bad in const [
        'http://example.test/x',
        'ws://example.test/x',
        'ftp://example.test/x',
        'file:///etc/hosts',
        '//example.test/x',
      ]) {
        expect(
          () => requireHttpsUrl(Uri.parse(bad)),
          throwsA(isA<ArgumentError>()),
          reason: '"$bad" must be refused before a socket opens',
        );
      }
    });

    test('a bad certificate is always rejected', () {
      // The callback never inspects the cert — any bad cert fails closed.
      expect(rejectBadCertificate(_FakeCert(), 'example.test', 443), isFalse);
    });

    test('the pin set exists and is empty until a real backend does', () {
      expect(OlfHttpClient.certificatePins, isEmpty);
      expect(OlfHttpClient.certificatePins, isA<Map<String, List<String>>>());
    });
  });

  test('no file outside the seam touches the network directly', () {
    // CWD is the `app` package root under `flutter test`; `core` is a sibling.
    const seam = 'lib/src/net/olf_http_client.dart';
    final roots = <String>['lib', '../core/lib'];

    // Network primitives that must only ever appear behind the seam.
    final forbidden = <RegExp>[
      RegExp(r'\bHttpClient\b'),
      RegExp(r'\bHttpServer\b'),
      RegExp(r'package:http/'),
      RegExp(r'\bWebSocket\b'),
      RegExp(r'\bSecureSocket\b'),
      RegExp(r'\bRawSocket\b'),
      RegExp(r'\bRawDatagramSocket\b'),
      RegExp(r'\bServerSocket\b'),
      RegExp(r'\bSocket\.connect\b'),
    ];

    final violations = <String>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart')) continue;
        if (entity.path.replaceAll(r'\', '/').endsWith(seam)) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final rule in forbidden) {
            if (rule.hasMatch(lines[i])) {
              violations.add('${entity.path}:${i + 1}  ${rule.pattern}');
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Network access must go through OlfHttpClient ($seam), not a raw '
          'client / socket / package:http. Route it through the seam.\n\n'
          '${violations.join('\n')}',
    );
  });
}

class _FakeCert implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
