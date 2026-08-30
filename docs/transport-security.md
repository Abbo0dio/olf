# Transport security baseline (p2.6)

`requirements.md` §3 / §8. **olf makes no network calls today** — no account, no
cloud, no telemetry. This slice puts the hardened defaults in place *now* so that
when Phase 6 (sync), 9 or 10 first open a socket, they inherit TLS-only, cannot
silently weaken it, and go through one chokepoint.

Three parts: platform config (Android + iOS), a Dart client seam, and a build
gate that fails if any of it is loosened.

## Android — `network_security_config.xml`

`app/android/app/src/main/res/xml/network_security_config.xml`, wired from the
`<application>` tag in `AndroidManifest.xml`:

```xml
android:usesCleartextTraffic="false"
android:networkSecurityConfig="@xml/network_security_config"
```

```xml
<base-config cleartextTrafficPermitted="false">
    <trust-anchors><certificates src="system" /></trust-anchors>
</base-config>
```

- **No cleartext, every API level.** `cleartextTrafficPermitted="false"` in
  `<base-config>` refuses plain `http://` app-wide regardless of the `minSdk`
  default, and `android:usesCleartextTraffic="false"` says the same at the
  manifest level.
- **System trust anchors only.** No `<certificates src="user" />` — a
  user-installed / MITM proxy CA is not trusted.
- **No `<debug-overrides>`** in the committed file (it can re-trust user CAs or
  cleartext for debug builds). The debug/profile manifests add only the
  `INTERNET` permission for Flutter tooling; they do not touch cleartext.

## iOS — App Transport Security

`app/ios/Runner/Info.plist`, made explicit rather than relying on the OS
default:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key><false/>
    <key>NSAllowsArbitraryLoadsForMedia</key><false/>
    <key>NSAllowsLocalNetworking</key><false/>
</dict>
```

No `NSExceptionDomains` — there are no per-host relaxations. ATS enforces TLS
1.2+, forward secrecy and a valid certificate chain for every connection.

## Dart — the `OlfHttpClient` seam

`app/lib/src/net/olf_http_client.dart` is the **only** sanctioned way olf may
ever talk to the network. It wraps `dart:io`'s `HttpClient` (no new dependency):

| Guarantee | How |
|---|---|
| https only | `requireHttpsUrl(url)` throws `ArgumentError` on any non-`https` scheme before a socket opens |
| fail closed on a bad cert | `HttpClient.badCertificateCallback` is wired to `rejectBadCertificate`, which always returns `false`; a feature has no handle on the inner client |
| pinning-ready | `OlfHttpClient.certificatePins` (`Map<String, List<String>>`, SPKI-SHA256, **empty today**); `_checkPins` throws for a host listed there until enforcement is wired, so a "pinned but unverified" host can never connect |

### Certificate pinning — how it plugs in

When the first backend host exists:

1. Add its SPKI-SHA256 pins to `OlfHttpClient.certificatePins` **and** to a
   `<domain-config><pin-set>` in `network_security_config.xml` (keep the two in
   step).
2. Implement enforcement in `OlfHttpClient` — with `dart:io` this is a
   `SecurityContext` with only the pinned chain trusted, or a leaf-SPKI check in
   a `connectionFactory` / a post-connect verification. Replace the `throw` in
   `_checkPins`.
3. `dart:io` has no built-in SPKI pinning helper. If a small, audited package is
   the cleaner path at that point, add it then — it is **not** pulled in
   speculatively now (see `DEVELOPMENT_PLAN.md` §9).

## The build gate

`.github/scripts/dependency_audit.dart` (the `dependency-audit` CI job) gained
`--net-config` and `--plist`. It **fails the build** if:

- any Android manifest has `android:usesCleartextTraffic="true"`;
- the network-security config says `cleartextTrafficPermitted="true"`, is missing
  the explicit `"false"`, or contains `<debug-overrides>`;
- the Info.plist sets any `NSAllowsArbitraryLoads*` / `NSAllowsLocalNetworking`
  to `<true/>`, or declares `NSExceptionDomains`.

XML/plist comments are stripped before scanning, so a warning comment that
*names* a forbidden token does not trip it. `core/test/dependency_audit_test.dart`
has passing + deliberately-failing fixtures for each check;
`app/test/net/transport_security_test.dart` unit-tests the seam and scans
`app/lib` + `core/lib` for any `HttpClient` / `package:http` / raw `Socket`
outside `olf_http_client.dart`.
