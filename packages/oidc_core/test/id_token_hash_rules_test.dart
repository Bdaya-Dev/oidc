@TestOn('vm')
library;

// Unit coverage of the `at_hash` / `c_hash` rules in `validateUser`, per
// `OidcIdTokenSource` (OpenID Connect Core 1.0):
//
// * authorizationEndpoint: at_hash REQUIRED with an access_token (§3.2.2.10
//   implicit, §3.3.2.11 hybrid); c_hash REQUIRED with a code (§3.3.2.11).
// * tokenEndpoint / refresh / storedSession: both OPTIONAL, checked only when
//   present (§3.1.3.8, §3.3.3.6, §12.2).
// * The hashes are judged from the response's own tokens
//   (`OidcIdTokenValidationContext.accessToken` / `authorizationCode`), never
//   from an access_token a signed-in user's merged token kept.
// * An id_token retained from an earlier response
//   (`OidcToken.idTokenRetainedFromPriorResponse`): refresh / storedSession
//   skip its hashes, because they bind the tokens of the response that issued
//   it (§12.2). Any other source requires neither, but compares a present one.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _accessToken = 'at-1';
final _metadata = OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});
const _code = 'code-1';

class _M extends OidcUserManagerBase {
  _M()
    : super(
        discoveryDocument: _metadata,
        clientCredentials: const OidcClientAuthentication.none(
          clientId: 'client-1',
        ),
        store: OidcMemoryStore(),
        settings: OidcUserManagerSettings(
          redirectUri: Uri.parse('com.example.app://cb'),
        ),
      );

  List<String> hashErrors(
    OidcUser user, [
    OidcIdTokenValidationContext context = const OidcIdTokenValidationContext(),
  ]) => validateUser(
    user: user,
    metadata: _metadata,
    context: context,
  ).map((e) => e.toString()).where((e) => e.contains('_hash')).toList();

  @override
  bool get isWeb => false;
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

/// base64url left-half SHA-256 hash (RS256 id_token), OIDC Core §3.2.2.9.
String _hash(String value) {
  final full = sha256.convert(ascii.encode(value)).bytes;
  return base64Url
      .encode(full.sublist(0, full.length ~/ 2))
      .replaceAll('=', '');
}

final _key = JsonWebKey.generate('RS256');

Future<OidcUser> _user({
  String? atHash,
  String? cHash,
  String? accessToken = _accessToken,
  bool retained = false,
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  final idToken =
      (JsonWebSignatureBuilder()
            ..jsonContent = {
              'iss': 'https://op.example.com',
              'sub': 'user-1',
              'aud': 'client-1',
              'exp': now + 3600,
              'iat': now,
              'at_hash': ?atHash,
              'c_hash': ?cHash,
            }
            ..addRecipient(_key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
  return OidcUser.fromIdToken(
    token: OidcToken(
      creationTime: clock.now(),
      idToken: idToken,
      accessToken: accessToken,
      tokenType: 'Bearer',
      // Written by `OidcUser.replaceToken` when a refresh keeps the id_token.
      extra: retained ? {OidcConstants_Store.allowExpiredIdToken: true} : null,
    ),
  );
}

/// A context for [source]. Like the manager's call sites, the authorization
/// endpoint passes the access_token of its response ([accessToken]); the
/// other sources leave it to the validated user's token.
OidcIdTokenValidationContext _ctx(
  OidcIdTokenSource source, {
  String? code,
  String? accessToken = _accessToken,
}) => OidcIdTokenValidationContext(
  source: source,
  authorizationCode: code,
  accessToken: source == OidcIdTokenSource.authorizationEndpoint
      ? accessToken
      : null,
);

void main() {
  final manager = _M();
  const notRequiredSources = [
    OidcIdTokenSource.tokenEndpoint,
    OidcIdTokenSource.refresh,
    OidcIdTokenSource.storedSession,
  ];

  test('the default context is the token endpoint with nothing extra', () {
    const context = OidcIdTokenValidationContext();
    expect(context.source, OidcIdTokenSource.tokenEndpoint);
    expect(context.authorizationCode, isNull);
    expect(context.accessToken, isNull);
    expect(context.maxAge, isNull);
  });

  test('toString does not leak the authorization code or access_token', () {
    final text = _ctx(
      OidcIdTokenSource.authorizationEndpoint,
      code: _code,
    ).toString();
    expect(text, isNot(contains(_code)));
    expect(text, isNot(contains(_accessToken)));
  });

  group('at_hash', () {
    for (final source in OidcIdTokenSource.values) {
      test('${source.name}: a matching at_hash passes', () async {
        final user = await _user(atHash: _hash(_accessToken));
        expect(manager.hashErrors(user, _ctx(source)), isEmpty);
      });

      test('${source.name}: a mismatched at_hash is rejected', () async {
        final user = await _user(atHash: _hash('another-token'));
        expect(manager.hashErrors(user, _ctx(source)), [
          contains('`at_hash` does not match the access_token'),
        ]);
      });

      test('${source.name}: no access_token means no at_hash rule', () async {
        final user = await _user(accessToken: null);
        expect(
          manager.hashErrors(user, _ctx(source, accessToken: null)),
          isEmpty,
        );
      });
    }

    group(
      "authorizationEndpoint: the response's access_token decides, not the "
      "user's (a signed-in user's merged token keeps the previous one)",
      () {
        test('none returned: a missing at_hash is accepted', () async {
          final user = await _user();
          expect(
            manager.hashErrors(
              user,
              _ctx(OidcIdTokenSource.authorizationEndpoint, accessToken: null),
            ),
            isEmpty,
          );
        });

        test('none returned: at_hash is not compared at all', () async {
          final user = await _user(atHash: _hash('something-else'));
          expect(
            manager.hashErrors(
              user,
              _ctx(OidcIdTokenSource.authorizationEndpoint, accessToken: null),
            ),
            isEmpty,
          );
        });

        test('one returned: at_hash is compared with it', () async {
          final user = await _user(atHash: _hash(_accessToken));
          expect(
            manager.hashErrors(
              user,
              _ctx(
                OidcIdTokenSource.authorizationEndpoint,
                accessToken: 'at-from-this-response',
              ),
            ),
            [contains('`at_hash` does not match the access_token')],
          );
        });
      },
    );

    test(
      "tokenEndpoint: a supplied access_token is used instead of the user's",
      () async {
        final user = await _user(atHash: _hash(_accessToken));
        expect(
          manager.hashErrors(
            user,
            const OidcIdTokenValidationContext(
              accessToken: 'at-from-this-response',
            ),
          ),
          [contains('`at_hash` does not match the access_token')],
        );
      },
    );

    test(
      'authorizationEndpoint: a missing at_hash with an access_token is '
      'rejected (§3.2.2.10, §3.3.2.11)',
      () async {
        final user = await _user();
        expect(
          manager.hashErrors(
            user,
            _ctx(OidcIdTokenSource.authorizationEndpoint),
          ),
          [contains('missing the required `at_hash` claim')],
        );
      },
    );

    for (final source in notRequiredSources) {
      test('${source.name}: a missing at_hash is accepted', () async {
        final user = await _user();
        expect(manager.hashErrors(user, _ctx(source)), isEmpty);
      });
    }
  });

  group('c_hash', () {
    for (final source in OidcIdTokenSource.values) {
      test('${source.name}: a matching c_hash passes', () async {
        final user = await _user(
          atHash: _hash(_accessToken),
          cHash: _hash(_code),
        );
        expect(manager.hashErrors(user, _ctx(source, code: _code)), isEmpty);
      });

      test('${source.name}: a mismatched c_hash is rejected', () async {
        final user = await _user(
          atHash: _hash(_accessToken),
          cHash: _hash('another-code'),
        );
        expect(manager.hashErrors(user, _ctx(source, code: _code)), [
          contains('`c_hash` does not match the authorization code'),
        ]);
      });

      test('${source.name}: no code means no c_hash rule', () async {
        final user = await _user(
          atHash: _hash(_accessToken),
          cHash: 'not-checked',
        );
        expect(manager.hashErrors(user, _ctx(source)), isEmpty);
      });
    }

    test(
      'authorizationEndpoint: a missing c_hash with a code is rejected '
      '(§3.3.2.11)',
      () async {
        final user = await _user(atHash: _hash(_accessToken));
        expect(
          manager.hashErrors(
            user,
            _ctx(OidcIdTokenSource.authorizationEndpoint, code: _code),
          ),
          [contains('missing the required `c_hash` claim')],
        );
      },
    );

    for (final source in notRequiredSources) {
      test('${source.name}: a missing c_hash is accepted', () async {
        final user = await _user(atHash: _hash(_accessToken));
        expect(manager.hashErrors(user, _ctx(source, code: _code)), isEmpty);
      });
    }
  });

  group('an id_token retained from an earlier response', () {
    for (final source in [
      OidcIdTokenSource.refresh,
      OidcIdTokenSource.storedSession,
    ]) {
      test(
        "${source.name}: its at_hash is not compared with the new token's "
        '(§12.2)',
        () async {
          final user = await _user(
            atHash: _hash('the-earlier-access-token'),
            retained: true,
          );
          expect(user.token.idTokenRetainedFromPriorResponse, isTrue);
          expect(manager.hashErrors(user, _ctx(source)), isEmpty);
        },
      );
    }

    for (final source in [
      OidcIdTokenSource.tokenEndpoint,
      OidcIdTokenSource.authorizationEndpoint,
    ]) {
      test(
        '${source.name}: a present at_hash is still compared (only a refresh '
        'may skip it)',
        () async {
          final user = await _user(
            atHash: _hash('the-earlier-access-token'),
            retained: true,
          );
          expect(manager.hashErrors(user, _ctx(source)), [
            contains('`at_hash` does not match the access_token'),
          ]);
        },
      );
    }

    test('no hash is required for it, whatever the source', () async {
      final user = await _user(retained: true);
      for (final source in OidcIdTokenSource.values) {
        expect(
          manager.hashErrors(user, _ctx(source, code: _code)),
          isEmpty,
          reason: source.name,
        );
      }
    });
  });

  group('OidcToken.idTokenRetainedFromPriorResponse', () {
    test('survives toJson / fromJson (the store round trip)', () {
      final token = OidcToken(
        creationTime: clock.now(),
        extra: {OidcConstants_Store.allowExpiredIdToken: true},
      );
      final restored = OidcToken.fromJson(
        jsonDecode(jsonEncode(token.toJson())) as Map<String, dynamic>,
      );
      expect(restored.idTokenRetainedFromPriorResponse, isTrue);
      expect(restored.allowExpiredIdToken, isTrue);
    });

    test('is never taken from a token response', () {
      final token = OidcToken.fromResponse(
        OidcTokenResponse.fromJson({
          'access_token': _accessToken,
          'token_type': 'Bearer',
          OidcConstants_Store.allowExpiredIdToken: true,
        }),
        sessionState: null,
      );
      expect(token.idTokenRetainedFromPriorResponse, isFalse);
      expect(token.allowExpiredIdToken, isFalse);
    });
  });
}
