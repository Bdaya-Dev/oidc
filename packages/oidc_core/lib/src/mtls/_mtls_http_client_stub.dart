import 'package:http/http.dart' as http;
import 'package:oidc_core/src/mtls/mtls_http_client.dart';

/// Stub for platforms without `dart:io` (web): a browser exposes no API for
/// fetch/XHR to present a client certificate.
bool get isSupported => false;

/// Always throws on this platform.
http.Client createHttpClient({
  required OidcMtlsClientCertificate certificate,
  required List<int>? trustedCertificates,
  required bool withTrustedRoots,
}) => throw UnsupportedError(
  'Mutual-TLS client certificates (RFC 8705) are not supported on web: '
  'browsers expose no API for fetch/XHR to present a client certificate.',
);
