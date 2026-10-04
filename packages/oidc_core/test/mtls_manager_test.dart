@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// RFC 8705 phase 2 (#386): the manager routes every back-channel request
/// through the single `resolveEndpoint` choke point, so that
/// `useMtlsEndpointAliases` sends them to `mtls_endpoint_aliases` end-to-end,
/// and refuses an mTLS client-auth method on web at init.

const _issuer = 'https://op.example.com';
const _mtlsHost = 'mtls.example.com';
const _conventionalHost = 'op.example.com';
final _signingKey = JsonWebKey.generate('RS256');

String _signIdToken() {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': 'user-1',
          'aud': 'client-1',
          'exp': now + 3600,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

class _Manager extends OidcUserManagerBase {
  _Manager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    this.isWeb = false,
  });

  @override
  final bool isWeb;

  /// When set, [getAuthorizationResponse] echoes back this code (with the
  /// request's own `state`) instead of short-circuiting with `null`, so
  /// [loginAuthorizationCodeFlow] drives a real code -> token exchange.
  /// `null` (the default) preserves the original "stop at the front channel"
  /// behavior the PAR-only scenarios rely on.
  String? codeToReturn;

  Future<OidcTokenResponse> exchangeTokenTest() =>
      exchangeToken(subjectToken: 'subject-token');

  Uri? resolveEndpointTest(OidcProviderMetadata metadata, String name) =>
      resolveEndpoint(metadata, name);

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    final code = codeToReturn;
    if (code == null) {
      return null;
    }
    return OidcAuthorizeResponse.fromJson({
      'code': code,
      'state': request.state,
    });
  }

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

/// Every endpoint an RP calls directly, at the conventional host, with an mTLS
/// alias for each at [_mtlsHost]. The front-channel endpoints are aliased too,
/// to prove the manager never follows those (RFC 8705 §5: an alias for an
/// endpoint the client does not call directly "SHOULD be ignored").
OidcProviderMetadata _metadata() {
  Map<String, String> endpoints(String host) => {
    'authorization_endpoint': 'https://$host/authorize',
    'token_endpoint': 'https://$host/token',
    'userinfo_endpoint': 'https://$host/userinfo',
    'revocation_endpoint': 'https://$host/revoke',
    'introspection_endpoint': 'https://$host/introspect',
    'device_authorization_endpoint': 'https://$host/device',
    'pushed_authorization_request_endpoint': 'https://$host/par',
    'end_session_endpoint': 'https://$host/logout',
  };
  return OidcProviderMetadata.fromJson({
    'issuer': _issuer,
    ...endpoints(_conventionalHost),
    'mtls_endpoint_aliases': endpoints(_mtlsHost),
  });
}

/// A fake OP that answers by path on either host and records every request.
MockClient _op(List<Uri> requests) => MockClient((req) async {
  requests.add(req.url);
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );
  switch (req.url.path) {
    case '/token':
      final grantType = Uri.splitQueryString(req.body)['grant_type'];
      if (grantType == OidcConstants_GrantType.deviceCode) {
        return json({'error': 'access_denied'}, 400);
      }
      return json({
        'access_token': 'at',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'refresh_token': 'rt',
        'id_token': _signIdToken(),
        'issued_token_type': OidcConstants_TokenExchange_TokenType.accessToken,
      });
    case '/userinfo':
      return json({'sub': 'user-1'});
    case '/revoke':
      return http.Response('', 200);
    case '/introspect':
      return json({'active': true});
    case '/device':
      return json({
        'device_code': 'dc',
        'user_code': 'uc',
        'verification_uri': 'https://op.example.com/verify',
        'expires_in': 60,
        'interval': 1,
      });
    case '/par':
      return json({'request_uri': 'urn:example:par', 'expires_in': 60}, 201);
  }
  return http.Response('{}', 404);
});

Future<_Manager> _build({
  required http.Client client,
  required bool useMtlsEndpointAliases,
  OidcClientAuthentication clientCredentials =
      const OidcClientAuthentication.tlsClientAuth(clientId: 'client-1'),
  bool isWeb = false,
  bool init = true,
}) async {
  final manager = _Manager(
    discoveryDocument: _metadata(),
    clientCredentials: clientCredentials,
    store: OidcMemoryStore(),
    httpClient: client,
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    isWeb: isWeb,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      initMode: OidcInitMode.blockingValidate,
      useMtlsEndpointAliases: useMtlsEndpointAliases,
      pushedAuthorizationRequestsMode:
          OidcPushedAuthorizationRequestsMode.always,
    ),
  );
  if (init) {
    await manager.init();
  }
  return manager;
}

/// Drives every back-channel request the manager makes — specifically every
/// call site that resolves `token_endpoint` (and the other back-channel
/// endpoints) through the `resolveEndpoint` choke point. There are THREE
/// distinct `token_endpoint` call sites exercised below (manual
/// `refreshToken()`, the authorization-code exchange, and the timer-shared
/// auto-refresh path via `getAccessToken(forceRefresh: true)`), plus the
/// password grant and RFC 8693 token exchange; a mutation that bypasses
/// `resolveEndpoint` at any ONE of them must turn this (or the caller's)
/// assertions RED, even though the others would still "cover" the
/// `token_endpoint` string.
Future<void> _exerciseEveryBackChannelEndpoint(_Manager manager) async {
  // token (password grant) + userinfo
  final user = await manager.loginPassword(username: 'u', password: 'p');
  expect(user, isNotNull);
  // token (refresh_token grant) -- the manual `_refreshToken` call site.
  expect(await manager.refreshToken(), isNotNull);
  // token (auto-refresh) -- the separate `_performAutoRefresh` call site,
  // shared with the timer-driven expiry path.
  expect(await manager.getAccessToken(forceRefresh: true), isNotNull);
  // token (RFC 8693 token exchange)
  await manager.exchangeTokenTest();
  // introspection
  expect((await manager.introspectToken()).active, isTrue);
  // revocation
  await manager.revokeAccessToken(forgetUser: false);
  await manager.revokeRefreshToken(forgetUser: false);
  // PAR (the front channel then goes to the authorization endpoint) +
  // the authorization-code -> token exchange (`handleSuccessfulAuthResponse`).
  // The OP's id_token in this fixture carries no `nonce` claim, so
  // `createUserFromToken` rejects it as a possible replay right after the
  // back-channel call completes -- by then the exchange (and its
  // `resolveEndpoint` choke point) has already been exercised.
  manager.codeToReturn = 'auth-code-1';
  await expectLater(
    manager.loginAuthorizationCodeFlow(),
    throwsA(isA<OidcException>()),
  );
  // device authorization (the token poll is refused, ending the flow)
  expect(await manager.loginDeviceCodeFlow(), isNull);
}

void main() {
  group('mTLS endpoint alias routing through the manager (RFC 8705 §5)', () {
    test(
      'useMtlsEndpointAliases: every back-channel request goes to the alias',
      () async {
        final requests = <Uri>[];
        final manager = await _build(
          client: _op(requests),
          useMtlsEndpointAliases: true,
        );

        await _exerciseEveryBackChannelEndpoint(manager);

        expect(
          requests.map((u) => u.path).toSet(),
          containsAll(<String>[
            '/token',
            '/userinfo',
            '/introspect',
            '/revoke',
            '/par',
            '/device',
          ]),
          reason: 'every back-channel endpoint must have been exercised',
        );
        expect(
          requests.where((u) => u.host != _mtlsHost),
          isEmpty,
          reason: 'no back-channel request may bypass mtls_endpoint_aliases',
        );
        await manager.dispose();
      },
    );

    test('setting off (default): aliases are ignored', () async {
      final requests = <Uri>[];
      final manager = await _build(
        client: _op(requests),
        useMtlsEndpointAliases: false,
      );

      await _exerciseEveryBackChannelEndpoint(manager);

      expect(requests, isNotEmpty);
      expect(requests.where((u) => u.host != _conventionalHost), isEmpty);
      await manager.dispose();
    });

    test('the choke point falls back to the top-level endpoint per endpoint, '
        'and never aliases a front-channel endpoint', () async {
      final manager = await _build(
        client: _op([]),
        useMtlsEndpointAliases: true,
      );
      final partial = OidcProviderMetadata.fromJson({
        'issuer': _issuer,
        'authorization_endpoint': '$_issuer/authorize',
        'end_session_endpoint': '$_issuer/logout',
        'token_endpoint': '$_issuer/token',
        'revocation_endpoint': '$_issuer/revoke',
        'mtls_endpoint_aliases': {
          'token_endpoint': 'https://$_mtlsHost/token',
          'authorization_endpoint': 'https://$_mtlsHost/authorize',
          'end_session_endpoint': 'https://$_mtlsHost/logout',
        },
      });

      expect(
        manager.resolveEndpointTest(
          partial,
          OidcConstants_ProviderMetadata.tokenEndpoint,
        ),
        Uri.parse('https://$_mtlsHost/token'),
      );
      expect(
        manager.resolveEndpointTest(
          partial,
          OidcConstants_ProviderMetadata.revocationEndpoint,
        ),
        Uri.parse('$_issuer/revoke'),
      );
      expect(
        manager.resolveEndpointTest(
          partial,
          OidcConstants_ProviderMetadata.authorizationEndpoint,
        ),
        Uri.parse('$_issuer/authorize'),
      );
      expect(
        manager.resolveEndpointTest(
          partial,
          OidcConstants_ProviderMetadata.endSessionEndpoint,
        ),
        Uri.parse('$_issuer/logout'),
      );
      await manager.dispose();
    });
  });

  group('mTLS client authentication on web', () {
    for (final auth in const [
      OidcClientAuthentication.tlsClientAuth(clientId: 'client-1'),
      OidcClientAuthentication.selfSignedTlsClientAuth(clientId: 'client-1'),
    ]) {
      test('${auth.location} throws UnsupportedError at init', () async {
        final requests = <Uri>[];
        final manager = await _build(
          client: _op(requests),
          useMtlsEndpointAliases: true,
          clientCredentials: auth,
          isWeb: true,
          init: false,
        );

        await expectLater(
          manager.init(),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(contains(auth.location), contains('RFC 8705')),
            ),
          ),
        );
        expect(requests, isEmpty, reason: 'fails before any network call');
      });
    }

    test(
      'useMtlsEndpointAliases: true throws UnsupportedError at init on web, '
      'even with a non-mTLS client authentication method',
      () async {
        final requests = <Uri>[];
        final manager = await _build(
          client: _op(requests),
          useMtlsEndpointAliases: true,
          clientCredentials: const OidcClientAuthentication.none(
            clientId: 'client-1',
          ),
          isWeb: true,
          init: false,
        );

        await expectLater(
          manager.init(),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(contains('useMtlsEndpointAliases'), contains('RFC 8705')),
            ),
          ),
        );
        expect(requests, isEmpty, reason: 'fails before any network call');
      },
    );

    test('a non-mTLS method still initializes on web', () async {
      final manager = await _build(
        client: _op([]),
        useMtlsEndpointAliases: false,
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'client-1',
        ),
        isWeb: true,
      );
      await manager.dispose();
    });

    test('mTLS methods still initialize off web', () async {
      final manager = await _build(
        client: _op([]),
        useMtlsEndpointAliases: false,
      );
      await manager.dispose();
    });
  });
}
