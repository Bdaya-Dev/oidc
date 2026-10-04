import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

import '_mtls_http_client_stub.dart'
    if (dart.library.io) '_mtls_http_client_io.dart'
    as impl;

/// The X.509 client certificate (and its private key) presented on the TLS
/// connection for RFC 8705 mutual-TLS client authentication and
/// certificate-bound access tokens.
///
/// The bytes are handed to `dart:io`'s `SecurityContext`
/// (`useCertificateChainBytes` / `usePrivateKeyBytes`), so they may be PEM, or
/// PKCS#12 when [password] is set.
class OidcMtlsClientCertificate {
  ///
  const OidcMtlsClientCertificate({
    required this.certificateChain,
    required this.privateKey,
    this.password,
  });

  /// The client certificate, optionally followed by its intermediate CA
  /// certificates (leaf first).
  final List<int> certificateChain;

  /// The private key matching the leaf of [certificateChain].
  final List<int> privateKey;

  /// The password protecting [certificateChain] / [privateKey], if any.
  final String? password;
}

/// Builds the certificate-bearing `http.Client` for RFC 8705 mutual TLS.
///
/// The client certificate lives in the transport, never in
/// [OidcClientAuthentication]: pass the returned client as the manager's
/// `httpClient` (or as `client:` to the [OidcEndpoints] functions), and pair it
/// with [OidcClientAuthentication.tlsClientAuth] or
/// [OidcClientAuthentication.selfSignedTlsClientAuth]. The same client then
/// presents the certificate at the token endpoint and on the UserInfo /
/// resource-server calls that RFC 8705 §3 requires for certificate-bound access
/// tokens. Enable `OidcUserManagerSettings.useMtlsEndpointAliases` when the
/// authorization server publishes `mtls_endpoint_aliases` (RFC 8705 §5).
///
/// Supported wherever `dart:io` is (VM, Android, iOS, macOS, Windows, Linux).
/// On web, [isSupported] is `false` and [createHttpClient] throws an
/// [UnsupportedError]: browsers expose no client-certificate API to fetch/XHR.
///
/// Apps that already hold a `dart:io` `SecurityContext` can skip this helper
/// and pass `IOClient(HttpClient(context: context))` directly.
abstract final class OidcMtls {
  /// Whether this platform can present a client certificate (`false` on web).
  static bool get isSupported => impl.isSupported;

  /// Returns an `http.Client` whose TLS connections present [certificate].
  ///
  /// [trustedCertificates] (PEM or PKCS#12 bytes) adds CA certificates trusted
  /// for the SERVER's certificate, e.g. a private CA behind the mTLS alias
  /// host; [withTrustedRoots] keeps the platform's default trust store as well.
  ///
  /// Throws an [UnsupportedError] on web.
  static http.Client createHttpClient({
    required OidcMtlsClientCertificate certificate,
    List<int>? trustedCertificates,
    bool withTrustedRoots = true,
  }) => impl.createHttpClient(
    certificate: certificate,
    trustedCertificates: trustedCertificates,
    withTrustedRoots: withTrustedRoots,
  );
}
