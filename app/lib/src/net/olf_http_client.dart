import 'dart:io';

/// The transport-security seam (p2.6).
///
/// **Nothing in olf calls the network yet.** This exists so that when Phase 6 /
/// 9 / 10 first make a request, they go through one chokepoint they cannot
/// accidentally weaken:
///
///  * **https only** — [requireHttpsUrl] throws on any non-`https` URL before a
///    socket is opened. `http://`, `ws://`, `file://` all fail closed.
///  * **fails closed on a bad certificate** — [rejectBadCertificate] is wired
///    to `HttpClient.badCertificateCallback` and always returns `false`, so a
///    hostname / chain / expiry problem aborts the connection. A feature has no
///    handle on the inner client to flip this.
///  * **pinning-ready** — [certificatePins] is the SPKI-SHA256 pin set, keyed
///    by host. It is empty today; when the first backend host exists, add its
///    pins here (mirroring the Android `network_security_config.xml`
///    `<pin-set>`) and enforce them in [_checkPins]. See
///    `docs/transport-security.md`.
///
/// `app/test/net/transport_security_test.dart` scans `app/lib` and `core/lib`
/// and fails if any *other* file uses `HttpClient`, `package:http`, `WebSocket`
/// or a raw `Socket` — this stays the only door.
class OlfHttpClient {
  OlfHttpClient({HttpClient? inner}) : _inner = _harden(inner ?? HttpClient());

  final HttpClient _inner;

  /// SPKI-SHA256 pins per host. Empty until a real backend exists — a pinned
  /// host with no enforcement path is a bug, so [_checkPins] throws rather than
  /// silently trusting it.
  static const Map<String, List<String>> certificatePins =
      <String, List<String>>{};

  static HttpClient _harden(HttpClient client) {
    client.badCertificateCallback = rejectBadCertificate;
    client.autoUncompress = true;
    return client;
  }

  Future<HttpClientResponse> getUrl(Uri url) => _send('GET', url);

  Future<HttpClientResponse> postUrl(Uri url) => _send('POST', url);

  Future<HttpClientResponse> _send(String method, Uri url) async {
    requireHttpsUrl(url);
    _checkPins(url.host);
    final request = await _inner.openUrl(method, url);
    return request.close();
  }

  static void _checkPins(String host) {
    if (certificatePins.containsKey(host)) {
      // Enforcement is a follow-up (see docs/transport-security.md); refuse
      // rather than connect to a host we claim to pin but do not verify.
      throw UnsupportedError(
        'certificate pinning for "$host" is declared but not yet enforced',
      );
    }
  }

  void close({bool force = false}) => _inner.close(force: force);
}

/// Returns [url] unchanged when it is `https`, otherwise throws. Extracted so a
/// unit test can exercise it without a socket.
Uri requireHttpsUrl(Uri url) {
  if (url.scheme.toLowerCase() != 'https') {
    throw ArgumentError.value(
      url.toString(),
      'url',
      'olf only makes https requests (scheme was "${url.scheme}")',
    );
  }
  return url;
}

/// `HttpClient.badCertificateCallback` implementation: always reject. A bad
/// certificate is never overridden, in any build.
bool rejectBadCertificate(X509Certificate cert, String host, int port) => false;
