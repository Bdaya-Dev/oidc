@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/mtls/_mtls_http_client_stub.dart' as web_stub;
import 'package:test/test.dart';

/// RFC 8705 phase 2 (#386): the certificate-bearing transport, driven against
/// a real local mutual-TLS server (`HttpServer.bindSecure(...,
/// requestClientCertificate: true)`) with fixture certificates from
/// `test/fixtures/mtls/` (regenerate with `generate.sh` there).

List<int> _fixture(String name) =>
    File('test/fixtures/mtls/$name').readAsBytesSync();

final List<int> _ca = _fixture('ca.pem');

final _pkiClientCert = OidcMtlsClientCertificate(
  certificateChain: _fixture('client.pem'),
  privateKey: _fixture('client.key'),
);

final _selfSignedClientCert = OidcMtlsClientCertificate(
  certificateChain: _fixture('self_signed_client.pem'),
  privateKey: _fixture('self_signed_client.key'),
);

/// A minimal mTLS authorization server.
///
/// It requests a client certificate on every connection and trusts both the
/// test CA (`tls_client_auth`, RFC 8705 §2.1) and the self-signed client
/// certificate (`self_signed_tls_client_auth`, RFC 8705 §2.2). `/token`
/// answers only when a certificate was presented; `/conventional-token` is the
/// non-mTLS endpoint an aliased client must never reach.
class _MtlsServer {
  _MtlsServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<_MtlsServer> start() async {
    final context = SecurityContext()
      ..useCertificateChainBytes(_fixture('server.pem'))
      ..usePrivateKeyBytes(_fixture('server.key'))
      ..setTrustedCertificatesBytes(_ca)
      ..setTrustedCertificatesBytes(_fixture('self_signed_client.pem'));
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    return _MtlsServer._(server);
  }

  final HttpServer _server;

  /// One entry per request: (path, presented client certificate subject).
  final requests = <(String, String?)>[];

  /// The `client_id` body parameters received at `/token`.
  final clientIds = <String?>[];

  Uri url(String path) => Uri.parse('https://127.0.0.1:${_server.port}$path');

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final subject = request.certificate?.subject;
    requests.add((request.uri.path, subject));
    final response = request.response..headers.contentType = ContentType.json;
    if (request.uri.path != '/token' || subject == null) {
      response
        ..statusCode = 401
        ..write(
          jsonEncode({
            'error': 'invalid_client',
            'error_description': 'no client certificate presented',
          }),
        );
    } else {
      clientIds.add(Uri.splitQueryString(body)['client_id']);
      response.write(
        jsonEncode({
          'access_token': 'cert-bound-at',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'issued_token_type':
              OidcConstants_TokenExchange_TokenType.accessToken,
        }),
      );
    }
    await response.close();
  }

  Future<void> close() => _server.close(force: true);
}

class _Manager extends OidcUserManagerBase {
  _Manager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  @override
  bool get isWeb => false;

  Future<OidcTokenResponse> exchangeTokenTest() =>
      exchangeToken(subjectToken: 'subject-token');

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;

  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) => const {};

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) => const Stream.empty();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) => const Stream.empty();
}

void main() {
  late _MtlsServer server;

  setUp(() async => server = await _MtlsServer.start());
  tearDown(() => server.close());

  test('OidcMtls is supported on the VM', () {
    expect(OidcMtls.isSupported, isTrue);
  });

  test('the web implementation is unsupported and throws clearly', () {
    expect(web_stub.isSupported, isFalse);
    expect(
      () => web_stub.createHttpClient(
        certificate: _pkiClientCert,
        trustedCertificates: null,
        withTrustedRoots: true,
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          contains('RFC 8705'),
        ),
      ),
    );
  });

  group('cert-bearing http.Client at the token endpoint', () {
    for (final (auth, cert, expectedSubject) in [
      (
        const OidcClientAuthentication.tlsClientAuth(clientId: 'pki-client'),
        _pkiClientCert,
        'CN=mtls-client',
      ),
      (
        const OidcClientAuthentication.selfSignedTlsClientAuth(
          clientId: 'self-signed-client',
        ),
        _selfSignedClientCert,
        'CN=self-signed-client',
      ),
    ]) {
      test('${auth.location}: presents the certificate, sends only '
          'client_id', () async {
        final client = OidcMtls.createHttpClient(
          certificate: cert,
          trustedCertificates: _ca,
          withTrustedRoots: false,
        );
        addTearDown(client.close);

        final response = await OidcEndpoints.token(
          tokenEndpoint: server.url('/token'),
          credentials: auth,
          request: OidcTokenRequest.clientCredentials(
            clientId: auth.clientId,
          ),
          client: client,
        );

        expect(response.accessToken, 'cert-bound-at');
        final (path, subject) = server.requests.single;
        expect(path, '/token');
        expect(subject, contains(expectedSubject));
        expect(server.clientIds.single, auth.clientId);
      });
    }

    test('without a client certificate the server rejects the client', () {
      final plain = IOClient(
        HttpClient(
          context: SecurityContext()..setTrustedCertificatesBytes(_ca),
        ),
      );
      addTearDown(plain.close);

      return expectLater(
        OidcEndpoints.token(
          tokenEndpoint: server.url('/token'),
          credentials: const OidcClientAuthentication.tlsClientAuth(
            clientId: 'pki-client',
          ),
          request: OidcTokenRequest.clientCredentials(clientId: 'pki-client'),
          client: plain,
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('end-to-end through the manager', () {
    for (final (auth, cert) in [
      (
        const OidcClientAuthentication.tlsClientAuth(clientId: 'pki-client'),
        _pkiClientCert,
      ),
      (
        const OidcClientAuthentication.selfSignedTlsClientAuth(
          clientId: 'self-signed-client',
        ),
        _selfSignedClientCert,
      ),
    ]) {
      test('${auth.location}: the httpClient seam + alias routing reach the '
          'mTLS token endpoint', () async {
        final client = OidcMtls.createHttpClient(
          certificate: cert,
          trustedCertificates: _ca,
          withTrustedRoots: false,
        );
        addTearDown(client.close);
        final manager = _Manager(
          discoveryDocument: OidcProviderMetadata.fromJson({
            'issuer': 'https://127.0.0.1',
            'token_endpoint': server.url('/conventional-token').toString(),
            'mtls_endpoint_aliases': {
              'token_endpoint': server.url('/token').toString(),
            },
          }),
          clientCredentials: auth,
          store: OidcMemoryStore(),
          httpClient: client,
          settings: OidcUserManagerSettings(
            redirectUri: Uri.parse('com.example.app://cb'),
            useMtlsEndpointAliases: true,
          ),
        );
        await manager.init();
        addTearDown(manager.dispose);

        final response = await manager.exchangeTokenTest();

        expect(response.accessToken, 'cert-bound-at');
        expect(server.requests.map((r) => r.$1), ['/token']);
        expect(server.clientIds.single, auth.clientId);
      });
    }
  });
}
