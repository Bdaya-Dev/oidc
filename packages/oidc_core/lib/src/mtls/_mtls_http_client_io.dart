import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:oidc_core/src/mtls/mtls_http_client.dart';

/// `dart:io` implementation: the certificate goes into a [SecurityContext]
/// that every connection of the returned client presents when the server
/// requests a client certificate.
bool get isSupported => true;

/// See `OidcMtls.createHttpClient`.
http.Client createHttpClient({
  required OidcMtlsClientCertificate certificate,
  required List<int>? trustedCertificates,
  required bool withTrustedRoots,
}) {
  final context = SecurityContext(withTrustedRoots: withTrustedRoots)
    ..useCertificateChainBytes(
      certificate.certificateChain,
      password: certificate.password,
    )
    ..usePrivateKeyBytes(
      certificate.privateKey,
      password: certificate.password,
    );
  if (trustedCertificates != null) {
    context.setTrustedCertificatesBytes(trustedCertificates);
  }
  return IOClient(HttpClient(context: context));
}
