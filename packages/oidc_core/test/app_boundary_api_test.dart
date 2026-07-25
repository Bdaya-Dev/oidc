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

const _issuer = 'https://op.example.com';
final _signingKey = JsonWebKey.generate('RS256');

String _signIdToken({
  String subject = 'user-1',
  Duration expiresIn = const Duration(hours: 1),
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': _issuer,
          'sub': subject,
          'aud': 'client-1',
          'exp': now + expiresIn.inSeconds,
          'iat': now,
        }
        ..addRecipient(_signingKey, algorithm: 'RS256'))
      .build()
      .toCompactSerialization();
}

Map<String, dynamic> _decodeSegment(String segment) =>
    jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(segment))))
        as Map<String, dynamic>;

({Map<String, dynamic> header, Map<String, dynamic> payload}) _parseProof(
  String proof,
) {
  final parts = proof.split('.');
  expect(parts, hasLength(3), reason: 'compact JWS has 3 segments');
  return (header: _decodeSegment(parts[0]), payload: _decodeSegment(parts[1]));
}

/// A concrete manager that lets a test seed a user and observe/short-circuit
/// the authorization request the `prompt=none` path builds.
class _M extends OidcUserManagerBase {
  _M({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
  });

  void seed(OidcUser? user) => userSubject.add(user);

  /// Every authorization request this manager was asked to perform, with the
  /// resolved platform options it was asked to perform it with.
  final authorizeCalls =
      <({OidcAuthorizeRequest request, OidcPlatformSpecificOptions options})>[];

  /// When set, [getAuthorizationResponse] throws this instead of returning
  /// `null` (models an OP answering the `prompt=none` request with an error).
  Object? authorizeError;

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    authorizeCalls.add((request: request, options: options));
    final error = authorizeError;
    if (error != null) {
      throw error;
    }
    return null;
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

OidcProviderMetadata _metadata() => OidcProviderMetadata.fromJson({
  'issuer': _issuer,
  'authorization_endpoint': '$_issuer/authorize',
  'token_endpoint': '$_issuer/token',
  'userinfo_endpoint': '$_issuer/userinfo',
});

Future<_M> _build(
  http.Client client, {
  OidcDPoPSettings? dpop,
  OidcPlatformSpecificOptions? options,
}) async {
  final manager = _M(
    discoveryDocument: _metadata(),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: client,
    keyStore: JsonWebKeyStore()..addKey(_signingKey),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
      dpop: dpop,
      options: options,
    ),
  );
  await manager.init();
  addTearDown(manager.dispose);
  return manager;
}

/// A user whose access token is still valid for [expiresIn].
///
/// A long, explicit `expiresIn` keeps the expiry timers armed far in the future
/// so the tests below drive the refresh themselves through
/// `getAccessToken`/`signInSilent` — no timer ever races them.
Future<OidcUser> _user({
  String? refreshToken = 'rt-1',
  Duration? expiresIn = const Duration(hours: 1),
}) => OidcUser.fromIdToken(
  token: OidcToken(
    creationTime: clock.now().toUtc(),
    idToken: _signIdToken(),
    accessToken: 'at-1',
    refreshToken: refreshToken,
    tokenType: 'Bearer',
    expiresIn: expiresIn,
  ),
);

String _tokenResponseBody({String accessToken = 'at-2'}) => jsonEncode({
  'access_token': accessToken,
  'token_type': 'Bearer',
  'expires_in': 3600,
  'id_token': _signIdToken(),
  'refresh_token': 'rt-2',
});

void main() {
  group('#424 typed failure classification on OidcException', () {
    test('the pre-existing constructors keep a null `kind` (nothing that '
        'threw before is suddenly classified)', () {
      const plain = OidcException('boom');
      expect(plain.kind, isNull);

      const server = OidcException.serverError(
        errorResponse: OidcErrorResponse(src: {}, error: 'invalid_request'),
      );
      expect(server.kind, isNull);
      expect(server.errorResponse?.error, 'invalid_request');
    });

    test('OidcInteractionRequiredException is still caught by `on '
        'OidcException` (additive, non-breaking)', () {
      OidcException? caught;
      try {
        throw const OidcInteractionRequiredException(message: 'need login');
      } on OidcException catch (e) {
        caught = e;
      }
      expect(caught, isA<OidcInteractionRequiredException>());
      expect(caught.kind, OidcTokenRefreshFailureKind.terminal);
    });

    test('OidcInteractionRequiredException.from preserves the original '
        'diagnostics of an OidcException', () {
      final rawResponse = http.Response('{"error":"invalid_grant"}', 400);
      final original = OidcException.serverError(
        errorResponse: const OidcErrorResponse(
          src: {},
          error: 'invalid_grant',
          errorDescription: 'token revoked',
        ),
        extra: const {'hint': 'x'},
        rawResponse: rawResponse,
      );

      final wrapped = OidcInteractionRequiredException.from(
        original,
        message: 'interactive re-authentication is required',
      );

      expect(wrapped.errorResponse?.error, 'invalid_grant');
      expect(wrapped.errorResponse?.errorDescription, 'token revoked');
      expect(wrapped.extra, const {'hint': 'x'});
      expect(wrapped.rawResponse, same(rawResponse));
      expect(wrapped.internalException, same(original));
      expect(wrapped.kind, OidcTokenRefreshFailureKind.terminal);
    });

    test('OidcInteractionRequiredException.from wraps a non-Oidc error as the '
        'internal exception', () {
      final wrapped = OidcInteractionRequiredException.from(
        const FormatException('nope'),
        message: 'need login',
      );
      expect(wrapped.internalException, isA<FormatException>());
      expect(wrapped.errorResponse, isNull);
    });

    test('toString names the concrete type', () {
      expect(
        const OidcInteractionRequiredException(message: 'm').toString(),
        startsWith('OidcInteractionRequiredException: m'),
      );
      expect(
        const OidcException('m').toString(),
        startsWith('OidcException: m'),
      );
    });
  });

  group('#421 getAccessToken', () {
    test(
      'returns null (does not throw) when there is no signed-in user',
      () async {
        final manager = await _build(
          MockClient((req) async => http.Response('{}', 404)),
        );
        expect(await manager.getAccessToken(), isNull);
      },
    );

    test('returns the cached token WITHOUT a network call when it is still '
        'valid for minValidity', () async {
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      expect(await manager.getAccessToken(), 'at-1');
      expect(tokenCalls, 0, reason: 'a fresh token must not be exchanged');
    });

    test('refreshes when the token expires within minValidity, and returns the '
        'NEW access token', () async {
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return http.Response(
              _tokenResponseBody(),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      // The seeded token is valid for 1h, so a 2h freshness margin forces the
      // refresh deterministically (no timer involved).
      final accessToken = await manager.getAccessToken(
        minValidity: const Duration(hours: 2),
      );
      expect(accessToken, 'at-2');
      expect(tokenCalls, 1);
      expect(manager.currentUser?.token.accessToken, 'at-2');
    });

    test(
      'forceRefresh exchanges even a token that is comfortably fresh',
      () async {
        var tokenCalls = 0;
        final manager = await _build(
          MockClient((req) async {
            if (req.url.path.endsWith('/token')) {
              tokenCalls++;
              return http.Response(
                _tokenResponseBody(),
                200,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', 404);
          }),
        );
        manager.seed(await _user());

        expect(await manager.getAccessToken(forceRefresh: true), 'at-2');
        expect(tokenCalls, 1);
      },
    );

    test('a token with no expires_in is returned as-is (unknown expiry is not '
        'treated as expired)', () async {
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user(expiresIn: null));

      expect(
        await manager.getAccessToken(minValidity: const Duration(days: 365)),
        'at-1',
      );
      expect(tokenCalls, 0);
    });

    test('CONCURRENT callers share ONE refresh-token exchange (the rotating '
        'refresh-token stampede #421 describes)', () async {
      final gate = Completer<http.Response>();
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return gate.future;
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      final calls = [
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
      ];
      await pumpEventQueue();
      expect(
        tokenCalls,
        1,
        reason: 'three concurrent callers must exchange the refresh token once',
      );

      gate.complete(
        http.Response(
          _tokenResponseBody(),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      expect(await Future.wait(calls), ['at-2', 'at-2', 'at-2']);
      expect(tokenCalls, 1);
    });

    test('throws OidcInteractionRequiredException when the stale session has '
        'no refresh token', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
      );
      manager.seed(await _user(refreshToken: null));

      await expectLater(
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        throwsA(isA<OidcInteractionRequiredException>()),
      );
    });

    test('throws OidcInteractionRequiredException on a TERMINAL refresh '
        'failure (invalid_grant)', () async {
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({'error': 'invalid_grant'}),
              400,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      await expectLater(
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        throwsA(
          isA<OidcInteractionRequiredException>()
              .having(
                (e) => e.kind,
                'kind',
                OidcTokenRefreshFailureKind.terminal,
              )
              .having(
                (e) => e.errorResponse?.error,
                'errorResponse.error',
                'invalid_grant',
              ),
        ),
      );
    });

    test('throws a `transient`-classified OidcException — NOT an '
        'interaction-required one — on a recoverable failure', () async {
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({'error': 'server_error'}),
              500,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      await expectLater(
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        throwsA(
          isA<OidcException>()
              .having(
                (e) => e.kind,
                'kind',
                OidcTokenRefreshFailureKind.transient,
              )
              .having(
                (e) => e is OidcInteractionRequiredException,
                'is interaction-required',
                isFalse,
              ),
        ),
      );
    });

    test('the refresh it drives is reported as a `manual` refresh failure '
        'event, not an autoExpiry one', () async {
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({'error': 'invalid_grant'}),
              400,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      final events = <OidcEvent>[];
      final sub = manager.events().listen(events.add);
      addTearDown(sub.cancel);

      await expectLater(
        manager.getAccessToken(minValidity: const Duration(hours: 2)),
        throwsA(isA<OidcInteractionRequiredException>()),
      );
      await pumpEventQueue();

      final failures = events.whereType<OidcTokenRefreshFailedEvent>().toList();
      expect(failures, hasLength(1));
      expect(failures.single.source, OidcTokenRefreshSource.manual);
      expect(failures.single.kind, OidcTokenRefreshFailureKind.terminal);
    });

    test('the legacy refreshToken() keeps its unconditional, un-coalesced '
        'behaviour (no silent change for existing callers)', () async {
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return http.Response(
              _tokenResponseBody(accessToken: 'at-$tokenCalls'),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      // A comfortably fresh token: getAccessToken skips the exchange, while
      // refreshToken() still performs it.
      expect(await manager.getAccessToken(), 'at-1');
      expect(tokenCalls, 0);
      await manager.refreshToken();
      expect(tokenCalls, 1);
    });
  });

  group('#422 public DPoP proof facade', () {
    test(
      'returns null (and has no thumbprint) when DPoP is disabled',
      () async {
        final manager = await _build(
          MockClient((req) async => http.Response('{}', 404)),
        );
        manager.seed(await _user());

        expect(manager.dpopThumbprint, isNull);
        expect(
          await manager.createDPoPProof(uri: Uri.parse('$_issuer/api')),
          isNull,
        );
        // A no-op rather than a crash when DPoP is off.
        manager.cacheDPoPNonce(Uri.parse('$_issuer/api'), 'n-1');
      },
    );

    test(
      'mints an RFC 9449 resource proof bound to the current access token',
      () async {
        final manager = await _build(
          MockClient((req) async => http.Response('{}', 404)),
          dpop: const OidcDPoPSettings(),
        );
        manager.seed(await _user());

        final proof = await manager.createDPoPProof(
          uri: Uri.parse('$_issuer/api/orders?page=2'),
          method: 'post',
        );
        expect(proof, isNotNull);
        final parsed = _parseProof(proof!);

        expect(parsed.header['typ'], oidcDPoPProofTyp);
        expect(parsed.header['jwk'], isA<Map<String, dynamic>>());
        expect(
          (parsed.header['jwk'] as Map<String, dynamic>).containsKey('d'),
          isFalse,
          reason: 'the embedded jwk must never carry private key material',
        );
        expect(parsed.payload['htm'], 'POST', reason: 'htm is uppercased');
        expect(
          parsed.payload['htu'],
          '$_issuer/api/orders',
          reason: 'htu drops the query string',
        );
        expect(parsed.payload['ath'], oidcDPoPAth('at-1'));
        expect(parsed.payload.containsKey('nonce'), isFalse);
      },
    );

    test('an explicit accessToken overrides the `ath` binding', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
        dpop: const OidcDPoPSettings(),
      );
      manager.seed(await _user());

      final proof = await manager.createDPoPProof(
        uri: Uri.parse('$_issuer/api'),
        accessToken: 'other-token',
      );
      expect(_parseProof(proof!).payload['ath'], oidcDPoPAth('other-token'));
    });

    test('returns null when DPoP is enabled but there is no access token to '
        'bind', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
        dpop: const OidcDPoPSettings(),
      );
      expect(
        await manager.createDPoPProof(uri: Uri.parse('$_issuer/api')),
        isNull,
      );
    });

    test('cacheDPoPNonce feeds a resource-server `DPoP-Nonce` into the NEXT '
        'proof for that endpoint only', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
        dpop: const OidcDPoPSettings(),
      );
      manager.seed(await _user());

      final resource = Uri.parse('$_issuer/api/orders');
      manager.cacheDPoPNonce(resource, 'nonce-abc');

      final withNonce = await manager.createDPoPProof(uri: resource);
      expect(_parseProof(withNonce!).payload['nonce'], 'nonce-abc');

      final other = await manager.createDPoPProof(
        uri: Uri.parse('$_issuer/api/invoices'),
      );
      expect(
        _parseProof(other!).payload.containsKey('nonce'),
        isFalse,
        reason: 'nonces are cached per endpoint',
      );
    });

    test('dpopThumbprint is the RFC 7638 thumbprint of the session proof key '
        '(the `cnf.jkt` value)', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
        dpop: const OidcDPoPSettings(),
      );
      manager.seed(await _user());

      final thumbprint = manager.dpopThumbprint;
      expect(thumbprint, isNotNull);
      // Stable across calls (the same per-session key is reused).
      expect(manager.dpopThumbprint, thumbprint);

      final proof = await manager.createDPoPProof(uri: Uri.parse('$_issuer/a'));
      final jwk = _parseProof(proof!).header['jwk'] as Map<String, dynamic>;
      expect(oidcJwkThumbprint(JsonWebKey.fromJson(jwk)!), thumbprint);
    });
  });

  group('#423 signInSilent', () {
    test('uses the refresh-token grant when one is available, WITHOUT touching '
        'the authorization endpoint', () async {
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return http.Response(
              _tokenResponseBody(),
              200,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      final user = await manager.signInSilent();
      expect(user?.token.accessToken, 'at-2');
      expect(tokenCalls, 1);
      expect(manager.authorizeCalls, isEmpty);
    });

    test('shares the SAME in-flight exchange as getAccessToken', () async {
      final gate = Completer<http.Response>();
      var tokenCalls = 0;
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            tokenCalls++;
            return gate.future;
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      final silent = manager.signInSilent();
      final acquired = manager.getAccessToken(
        minValidity: const Duration(hours: 2),
      );
      await pumpEventQueue();
      expect(tokenCalls, 1);

      gate.complete(
        http.Response(
          _tokenResponseBody(),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      expect((await silent)?.token.accessToken, 'at-2');
      expect(await acquired, 'at-2');
      expect(tokenCalls, 1);
    });

    test('throws OidcInteractionRequiredException when the refresh token is '
        'terminally rejected', () async {
      final manager = await _build(
        MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
              jsonEncode({'error': 'invalid_grant'}),
              400,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      manager.seed(await _user());

      await expectLater(
        manager.signInSilent(),
        throwsA(isA<OidcInteractionRequiredException>()),
      );
    });

    test('falls back to a hidden-iframe `prompt=none` authorization request '
        'when there is no refresh token', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
      );
      manager.seed(await _user(refreshToken: null));

      await manager.signInSilent(timeout: const Duration(seconds: 3));

      expect(manager.authorizeCalls, hasLength(1));
      final call = manager.authorizeCalls.single;
      expect(call.request.prompt, ['none']);
      expect(
        call.options.web.navigationMode,
        OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
      );
      expect(call.options.web.hiddenIframeTimeout, const Duration(seconds: 3));
    });

    test('the forced hidden-iframe options preserve every OTHER configured '
        'option (web and native alike)', () async {
      const configured = OidcPlatformSpecificOptions(
        web: OidcPlatformSpecificOptions_Web(
          broadcastChannel: 'custom/channel',
          popupWidth: 123,
          popupHeight: 456,
          hiddenIframeTimeout: Duration(seconds: 42),
        ),
      );
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
        options: configured,
      );
      manager.seed(await _user(refreshToken: null));

      await manager.signInSilent();

      final options = manager.authorizeCalls.single.options;
      expect(options.web.broadcastChannel, 'custom/channel');
      expect(options.web.popupWidth, 123);
      expect(options.web.popupHeight, 456);
      expect(
        options.web.hiddenIframeTimeout,
        const Duration(seconds: 42),
        reason: 'an omitted timeout keeps the configured one',
      );
      expect(options.android, same(configured.android));
      expect(options.ios, same(configured.ios));
      expect(options.macos, same(configured.macos));
      expect(options.linux, same(configured.linux));
      expect(options.windows, same(configured.windows));
    });

    test('forwards scopeOverride and extraParameters to the prompt=none '
        'request', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
      );
      manager.seed(await _user(refreshToken: null));

      await manager.signInSilent(
        scopeOverride: const ['openid', 'orders'],
        extraParameters: const {'acme': 'yes'},
      );

      final request = manager.authorizeCalls.single.request;
      expect(request.scope, ['openid', 'orders']);
      expect(request.extra['acme'], 'yes');
    });

    for (final code in const [
      'login_required',
      'interaction_required',
      'consent_required',
      'account_selection_required',
    ]) {
      test('maps a `$code` prompt=none response to '
          'OidcInteractionRequiredException', () async {
        final manager = await _build(
          MockClient((req) async => http.Response('{}', 404)),
        );
        manager.seed(await _user(refreshToken: null));
        manager.authorizeError = OidcException.serverError(
          errorResponse: OidcErrorResponse(src: const {}, error: code),
        );

        await expectLater(
          manager.signInSilent(),
          throwsA(
            isA<OidcInteractionRequiredException>()
                .having((e) => e.errorResponse?.error, 'error code', code)
                .having(
                  (e) => e.kind,
                  'kind',
                  OidcTokenRefreshFailureKind.terminal,
                ),
          ),
        );
      });
    }

    test('does NOT swallow an unrelated authorization error into an '
        'interaction-required one', () async {
      final manager = await _build(
        MockClient((req) async => http.Response('{}', 404)),
      );
      manager.seed(await _user(refreshToken: null));
      manager.authorizeError = OidcException.serverError(
        errorResponse: const OidcErrorResponse(
          src: {},
          error: 'invalid_request',
        ),
      );

      await expectLater(
        manager.signInSilent(),
        throwsA(
          isA<OidcException>().having(
            (e) => e is OidcInteractionRequiredException,
            'is interaction-required',
            isFalse,
          ),
        ),
      );
    });
  });
}
