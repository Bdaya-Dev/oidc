@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';
import 'package:test/test.dart';

void main() {
  group('OidcMonitorSessionResult subtypes', () {
    test('error result reports isError only', () {
      const r = OidcErrorMonitorSessionResult();
      expect(r.isError(), isTrue);
      expect(r.isValidResult(), isFalse);
      expect(r.isChanged(), isFalse);
      expect(r.getUnknownResult(), isNull);
    });

    test('valid unchanged result', () {
      const r = OidcValidMonitorSessionResult(changed: false);
      expect(r.isError(), isFalse);
      expect(r.isValidResult(), isTrue);
      expect(r.isChanged(), isFalse);
      expect(r.getUnknownResult(), isNull);
    });

    test('valid changed result reports isChanged', () {
      const r = OidcValidMonitorSessionResult(changed: true);
      expect(r.isValidResult(), isTrue);
      expect(r.isChanged(), isTrue);
    });

    test('unknown result exposes its raw data', () {
      const r = OidcUnknownMonitorSessionResult(data: 'raw-value');
      expect(r.isError(), isFalse);
      expect(r.isValidResult(), isFalse);
      expect(r.isChanged(), isFalse);
      expect(r.getUnknownResult(), 'raw-value');
    });

    test('base result answers all predicates negatively', () {
      const r = OidcMonitorSessionResult();
      expect(r.isError(), isFalse);
      expect(r.isValidResult(), isFalse);
      expect(r.isChanged(), isFalse);
      expect(r.getUnknownResult(), isNull);
    });
  });

  group('OidcMonitorSessionStatusRequest', () {
    test('carries all fields', () {
      const req = OidcMonitorSessionStatusRequest(
        clientId: 'client-1',
        sessionState: 'sess-1',
        interval: Duration(seconds: 3),
      );
      expect(req.clientId, 'client-1');
      expect(req.sessionState, 'sess-1');
      expect(req.interval, const Duration(seconds: 3));
    });
  });

  group('OidcIntrospectionResponse getters', () {
    test('reads every typed member from a rich response', () {
      final resp = OidcIntrospectionResponse.fromJson({
        'active': true,
        'scope': 'openid profile',
        'client_id': 'client-42',
        'username': 'alice',
        'token_type': 'Bearer',
        'sub': 'subject-1',
        'iss': 'https://op.example.com',
        'jti': 'jwt-id-1',
        'aud': ['a', 'b'],
        'exp': 1000,
        'iat': 900,
        'nbf': 950,
        'custom': 'x',
      });
      expect(resp.active, isTrue);
      expect(resp.scope, 'openid profile');
      expect(resp.clientId, 'client-42');
      expect(resp.username, 'alice');
      expect(resp.tokenType, 'Bearer');
      expect(resp.subject, 'subject-1');
      expect(resp.issuer, 'https://op.example.com');
      expect(resp.jwtId, 'jwt-id-1');
      expect(resp.audience, ['a', 'b']);
      expect(
        resp.expiry,
        DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
      );
      expect(
        resp.issuedAt,
        DateTime.fromMillisecondsSinceEpoch(900 * 1000, isUtc: true),
      );
      expect(
        resp.notBefore,
        DateTime.fromMillisecondsSinceEpoch(950 * 1000, isUtc: true),
      );
      // Non-standard members remain reachable via the source map operator.
      expect(resp['custom'], 'x');
    });

    test('single-string aud is wrapped in a list', () {
      final resp = OidcIntrospectionResponse.fromJson({
        'active': true,
        'aud': 'only-one',
      });
      expect(resp.audience, ['only-one']);
    });

    test('absent aud and numeric dates return null', () {
      final resp = OidcIntrospectionResponse.fromJson({'active': false});
      expect(resp.active, isFalse);
      expect(resp.audience, isNull);
      expect(resp.expiry, isNull);
      expect(resp.issuedAt, isNull);
      expect(resp.notBefore, isNull);
      expect(resp.scope, isNull);
    });
  });

  group('OidcStepUpChallenge.toString', () {
    test('includes scheme, error, acrValues and maxAge', () {
      final challenge = OidcStepUpChallenge.parse(
        'Bearer error="insufficient_user_authentication", '
        'acr_values="urn:acr:1 urn:acr:2", max_age=120',
      );
      expect(challenge, isNotNull);
      expect(challenge!.isInsufficientUserAuthentication, isTrue);
      final text = challenge.toString();
      expect(text, contains('OidcStepUpChallenge'));
      expect(text, contains('Bearer'));
      expect(
        text,
        contains(OidcStepUpChallenge.insufficientUserAuthenticationError),
      );
      expect(text, contains('urn:acr:1'));
      expect(text, contains('0:02:00'));
    });
  });

  group('JsonBasedRequest / JsonBasedResponse base behaviour', () {
    test('operator []= writes into extra and toMap surfaces it', () {
      final req = OidcTokenRequest.clientCredentials(
        clientId: 'c1',
        extra: <String, dynamic>{},
      )..['custom_field'] = 'v';
      expect(req.extra['custom_field'], 'v');
      expect(req.toMap()['custom_field'], 'v');
    });

    test('response operator [] and toString reflect the source map', () {
      final resp = OidcIntrospectionResponse.fromJson({
        'active': true,
        'anything': 42,
      });
      expect(resp['anything'], 42);
      expect(resp.toString(), contains('anything'));
    });

    test('readSrcMap returns the whole source map', () {
      final src = {'active': true, 'k': 'v'};
      expect(readSrcMap(src, 'ignored-key'), same(src));
    });
  });

  group('OidcOfflineAuthErrorHandler remaining branches', () {
    test('categorizeOidcError maps service_unavailable to serverError', () {
      final type = OidcOfflineAuthErrorHandler.categorizeOidcError(
        OidcErrorResponse.fromJson({'error': 'service_unavailable'}),
      );
      expect(type, OfflineAuthErrorType.serverError);
    });

    test('categorizeOidcError maps temporarily_unavailable to serverError', () {
      final type = OidcOfflineAuthErrorHandler.categorizeOidcError(
        OidcErrorResponse.fromJson({'error': 'temporarily_unavailable'}),
      );
      expect(type, OfflineAuthErrorType.serverError);
    });

    test('categorizeOidcError maps an unknown error code to clientError', () {
      final type = OidcOfflineAuthErrorHandler.categorizeOidcError(
        OidcErrorResponse.fromJson({'error': 'some_unmapped_error'}),
      );
      expect(type, OfflineAuthErrorType.clientError);
    });

    test('an unclassifiable error is unknown and allowed to continue', () {
      final type = OidcOfflineAuthErrorHandler.categorizeError(Object());
      expect(type, OfflineAuthErrorType.unknown);
      expect(
        OidcOfflineAuthErrorHandler.shouldContinueInOfflineMode(
          error: Object(),
          supportOfflineAuth: true,
        ),
        isTrue,
        reason:
            'unknown errors are treated conservatively (stay online-cached)',
      );
    });

    test('getOfflineModeReason covers every error type', () {
      final reasons = {
        for (final t in OfflineAuthErrorType.values)
          t: OidcOfflineAuthErrorHandler.getOfflineModeReason(t),
      };
      expect(
        reasons[OfflineAuthErrorType.networkUnavailable],
        OfflineModeReason.networkUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.networkTimeout],
        OfflineModeReason.networkUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.serverError],
        OfflineModeReason.serverUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.sslError],
        OfflineModeReason.serverUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.authenticationError],
        OfflineModeReason.serverUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.clientError],
        OfflineModeReason.serverUnavailable,
      );
      expect(
        reasons[OfflineAuthErrorType.unknown],
        OfflineModeReason.serverUnavailable,
      );
    });

    test('getErrorMessage produces a distinct message per type', () {
      final messages = {
        for (final t in OfflineAuthErrorType.values)
          OidcOfflineAuthErrorHandler.getErrorMessage(t),
      };
      expect(messages, hasLength(OfflineAuthErrorType.values.length));
    });
  });

  group('OidcUserManagerHooks execute* run the default execution', () {
    final metadata = OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'token_endpoint': 'https://op.example.com/token',
    });
    final hooks = OidcUserManagerHooks();

    test('executeToken runs default when no token hook is set', () async {
      final response = OidcTokenResponse.fromJson({'access_token': 'at'});
      final out = await hooks.executeToken(
        request: OidcTokenHookRequest(
          metadata: metadata,
          tokenEndpoint: metadata.tokenEndpoint!,
          request: OidcTokenRequest.clientCredentials(clientId: 'c1'),
          credentials: const OidcClientAuthentication.none(clientId: 'c1'),
          headers: const {},
          options: const OidcPlatformSpecificOptions(),
          client: null,
        ),
        defaultExecution: (_) async => response,
      );
      expect(out, same(response));
    });

    test('executeAuthorization runs default when no hook is set', () async {
      final response = OidcAuthorizeResponse.fromJson({'code': 'c'});
      final out = await hooks.executeAuthorization(
        request: OidcAuthorizationHookRequest(
          metadata: metadata,
          request: OidcAuthorizeRequest(
            clientId: 'c1',
            redirectUri: Uri.parse('com.example://cb'),
            responseType: const ['code'],
            scope: const ['openid'],
          ),
          options: const OidcPlatformSpecificOptions(),
          preparationResult: const {},
        ),
        defaultExecution: (_) async => response,
      );
      expect(out, same(response));
    });

    test('executeRevocation runs default when no hook is set', () async {
      final response = OidcRevocationResponse.fromJson(const {});
      final out = await hooks.executeRevocation(
        request: OidcRevocationHookRequest(
          metadata: metadata,
          revocationEndpoint: Uri.parse('https://op.example.com/revoke'),
          request: OidcRevocationRequest(token: 't'),
          options: const OidcPlatformSpecificOptions(),
          client: null,
          credentials: const OidcClientAuthentication.none(clientId: 'c1'),
          headers: const {},
        ),
        defaultExecution: (_) async => response,
      );
      expect(out, same(response));
    });
  });

  group('OidcHookGroup.modifyExecution without an execution hook', () {
    test('falls back to the default execution', () async {
      final group = OidcHookGroup<String, String>(hooks: []);
      final result = await group.modifyExecution(
        'in',
        (req) async => 'out:$req',
      );
      expect(result, 'out:in');
    });
  });

  group('defaultOfflineRefreshRetryDelay backoff', () {
    test('first failure yields the 30s base delay', () {
      expect(defaultOfflineRefreshRetryDelay(1), const Duration(seconds: 30));
    });
    test('second failure doubles to 1 minute', () {
      expect(defaultOfflineRefreshRetryDelay(2), const Duration(minutes: 1));
    });
    test('large failure counts are capped at 5 minutes', () {
      expect(defaultOfflineRefreshRetryDelay(10), const Duration(minutes: 5));
    });
  });

  group('OidcTokenResponse.isOidc', () {
    test('true when an id_token is present', () {
      expect(
        OidcTokenResponse.fromJson({'id_token': 'x'}).isOidc,
        isTrue,
      );
    });
    test('false when the id_token is empty or missing', () {
      expect(OidcTokenResponse.fromJson({'id_token': ''}).isOidc, isFalse);
      expect(OidcTokenResponse.fromJson(const {}).isOidc, isFalse);
    });
  });

  group('OidcToken.fromResponse override plumbing', () {
    test('applies overrideExpiresIn and sessionState', () {
      final token = OidcToken.fromResponse(
        OidcTokenResponse.fromJson({
          'access_token': 'at',
          'token_type': 'Bearer',
        }),
        overrideExpiresIn: const Duration(minutes: 42),
        sessionState: 'sess-xyz',
      );
      expect(token.accessToken, 'at');
      expect(token.expiresIn, const Duration(minutes: 42));
      expect(token.sessionState, 'sess-xyz');
    });
  });

  group('OidcTokenRequest secondary constructors', () {
    test('password constructor sets the password grant', () {
      final req = OidcTokenRequest.password(
        username: 'u',
        password: 'p',
        scope: const ['openid'],
        clientId: 'c1',
      );
      expect(req.grantType, OidcConstants_GrantType.password);
      expect(req.username, 'u');
      expect(req.password, 'p');
      expect(req.refreshToken, isNull);
    });

    test('saml2 constructor sets the assertion and grant', () {
      final req = OidcTokenRequest.saml2(
        assertion: 'the-assertion',
        scope: const ['openid'],
        clientId: 'c1',
      );
      expect(req.grantType, OidcConstants_GrantType.saml2Bearer);
      expect(req.assertion, 'the-assertion');
    });

    test('primary constructor is usable directly', () {
      final req = OidcTokenRequest(
        grantType: OidcConstants_GrantType.authorizationCode,
        clientId: 'c1',
        code: 'the-code',
        redirectUri: Uri.parse('com.example://cb'),
      );
      expect(req.grantType, OidcConstants_GrantType.authorizationCode);
      expect(req.code, 'the-code');
    });
  });

  group('Event const constructors preserve their payload', () {
    final at = DateTime.utc(2026, 3, 4);
    final token = OidcToken(
      accessToken: 'at',
      tokenType: 'Bearer',
      creationTime: at,
    );

    test('OidcTokenExpiredEvent', () {
      final e = OidcTokenExpiredEvent(currentToken: token, at: at);
      expect(e.currentToken, same(token));
      expect(e.at, at);
    });
    test('OidcTokenExpiringEvent', () {
      final e = OidcTokenExpiringEvent(currentToken: token, at: at);
      expect(e.currentToken, same(token));
      expect(e.at, at);
    });
    test('OidcOfflineModeEnteredEvent', () {
      final e = OidcOfflineModeEnteredEvent(
        reason: OfflineModeReason.networkUnavailable,
        at: at,
        currentToken: token,
      );
      expect(e.reason, OfflineModeReason.networkUnavailable);
      expect(e.currentToken, same(token));
    });
    test('OidcOfflineModeExitedEvent', () {
      final e = OidcOfflineModeExitedEvent(networkRestored: true, at: at);
      expect(e.networkRestored, isTrue);
      expect(e.at, at);
    });
    test('OidcOfflineAuthWarningEvent', () {
      final e = OidcOfflineAuthWarningEvent(
        warningType: OfflineAuthWarningType.usingExpiredToken,
        message: 'hi',
        at: at,
      );
      expect(e.warningType, OfflineAuthWarningType.usingExpiredToken);
      expect(e.message, 'hi');
    });
  });

  group('OidcRequestObjectSettings / OidcIdTokenVerificationOptions', () {
    test('request object settings expose their configuration', () {
      final key = JsonWebKey.generate('RS256');
      final settings = OidcRequestObjectSettings(
        signingKey: key,
        algorithm: 'RS256',
      );
      expect(settings.signingKey, same(key));
      expect(settings.algorithm, 'RS256');
      expect(settings.lifetime, const Duration(minutes: 5));
      expect(settings.clockSkew, Duration.zero);
    });

    test('id token verification options default to non-validating', () {
      const options = OidcIdTokenVerificationOptions();
      expect(options.validateAudience, isFalse);
      expect(options.validateIssuer, isFalse);
      expect(options.expiryTolerance, Duration.zero);
      expect(options.keyStore, isNull);
    });
  });

  group('OidcInternalUtilities.sendWithClient', () {
    test('uses a provided client without disposing it', () async {
      final client = MockClient(
        (req) async => http.Response('hello', 200),
      );
      final res = await OidcInternalUtilities.sendWithClient(
        client: client,
        request: http.Request('GET', Uri.parse('https://op.example.com/x')),
      );
      expect(res.statusCode, 200);
      expect(res.body, 'hello');
      // The client was borrowed, so it is still usable afterwards.
      final again = await client.get(Uri.parse('https://op.example.com/y'));
      expect(again.statusCode, 200);
    });

    test(
      'creates and disposes its own client when none is provided',
      () async {
        // A null client makes the helper allocate (and, in its finally block,
        // dispose) a real http.Client. Point it at a closed local port so the
        // send fails immediately without any external network dependency.
        await expectLater(
          OidcInternalUtilities.sendWithClient(
            client: null,
            request: http.Request(
              'GET',
              Uri.parse('http://127.0.0.1:1/never'),
            ),
          ),
          throwsA(isA<Object>()),
        );
      },
    );
  });

  group('OidcValueStream', () {
    test('caches its value and reports closed state', () async {
      final stream = OidcValueStream<int>(1);
      expect(stream.value, 1);
      expect(stream.isClosed, isFalse);
      stream.add(2);
      expect(stream.value, 2);
      await stream.close();
      expect(stream.isClosed, isTrue);
      // A no-op emit after close keeps the last value and does not throw.
      stream.add(3);
      expect(stream.value, 3);
    });
  });

  group('OidcPreLogoutEvent', () {
    test('const constructor stores the current user', () async {
      final key = JsonWebKey.generate('RS256');
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final idToken =
          (JsonWebSignatureBuilder()
                ..jsonContent = {
                  'iss': 'https://op.example.com',
                  'sub': 'user-1',
                  'aud': 'client-1',
                  'iat': now,
                  'exp': now + 3600,
                }
                ..addRecipient(key, algorithm: 'RS256'))
              .build()
              .toCompactSerialization();
      final user = await OidcUser.fromIdToken(
        token: OidcToken(
          creationTime: DateTime.utc(2026, 3, 4),
          idToken: idToken,
          accessToken: 'at',
          tokenType: 'Bearer',
        ),
        keystore: JsonWebKeyStore()..addKey(key),
      );
      final event = OidcPreLogoutEvent(
        currentUser: user,
        at: DateTime.utc(2026, 3, 4),
      );
      expect(event.currentUser, same(user));
    });
  });
}
