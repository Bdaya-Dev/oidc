@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

// `hybrid_flow_test.dart` proves the front-channel VALIDATOR is correct, and
// `user_manager_base.dart` already calls it before exchanging the code, so the
// response half of OIDC Core §3.3.2 is done.
//
// What is missing is the request half. `loginImplicitFlow` is the only public
// entry point that lets a caller choose `response_type`, and it hardcodes
// `grantType: implicit`, which takes tokens straight from the front channel and
// never touches the token endpoint. Ask it for a hybrid response type and you
// get an authorization CODE you never redeem, plus front-channel tokens the
// hybrid flow does not intend you to use as the final credentials.
//
// The README's "no hybrid flow support yet" describes this gap and nothing
// wider: the validation, the c_hash binding, and the code exchange all exist.
//
// This asserts the effect that distinguishes the two, rather than which method
// was called: after a hybrid login the access token must be the one the TOKEN
// ENDPOINT issued, not the one that came back on the redirect.

class _TestManager extends OidcUserManagerBase {
  _TestManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    required this.cannedResponse,
    super.keyStore,
    super.httpClient,
  });

  /// The authorize response the "browser" comes back with.
  Future<OidcAuthorizeResponse> Function(OidcAuthorizeRequest request)
  cannedResponse;

  @override
  bool get isWeb => false;
  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => cannedResponse(request);
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

final _metadata = OidcProviderMetadata.fromJson({
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

final _signingKey = JsonWebKey.generate('RS256');

Future<String> _signIdToken(Map<String, dynamic> claims) async {
  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..addRecipient(_signingKey, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

/// base64url left-half SHA-256 hash (RS256 id_token).
String _hash(String value) {
  final full = sha256.convert(ascii.encode(value)).bytes;
  return base64Url
      .encode(full.sublist(0, full.length ~/ 2))
      .replaceAll('=', '');
}

Map<String, dynamic> _claims({
  required String nonce,
  String? cHash,
  String? atHash,
}) => {
  'iss': 'https://op.example.com',
  'sub': 'user-1',
  'aud': 'client-1',
  'azp': 'client-1',
  'nonce': nonce,
  'exp':
      clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
  'c_hash': ?cHash,
  'at_hash': ?atHash,
};

void main() {
  test('a hybrid login redeems the code instead of keeping front-channel '
      'tokens', () async {
    var tokenEndpointCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
        tokenEndpointCalls++;
        final idToken = await _signIdToken(_claims(nonce: _capturedNonce));
        return http.Response(
          jsonEncode({
            'access_token': 'FROM-TOKEN-ENDPOINT',
            'token_type': 'Bearer',
            'id_token': idToken,
            'expires_in': 3600,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final manager = _TestManager(
      discoveryDocument: _metadata,
      clientCredentials: const OidcClientAuthentication.none(
        clientId: 'client-1',
      ),
      store: OidcMemoryStore(),
      settings: OidcUserManagerSettings(
        redirectUri: Uri.parse('com.example.app://cb'),
      ),
      keyStore: JsonWebKeyStore()..addKey(_signingKey),
      httpClient: client,
      cannedResponse: (request) async {
        // A conforming OP echoes the nonce it was sent and binds the code with
        // c_hash. Both have to be minted HERE, because the nonce is generated
        // per-request and is not known before the request is built -- signing a
        // token up front with a stand-in nonce is exactly the replay the
        // validator rejects.
        _capturedNonce = request.nonce!;
        const code = 'the-code';
        return OidcAuthorizeResponse.fromJson({
          'state': request.state,
          'code': code,
          'id_token': await _signIdToken(
            _claims(nonce: request.nonce!, cHash: _hash(code)),
          ),
          'access_token': 'FROM-FRONT-CHANNEL',
        });
      },
    );
    await manager.init();

    // response_type defaults to `code id_token`, the canonical hybrid pair.
    final user = await manager.loginHybridFlow();

    expect(
      tokenEndpointCalls,
      1,
      reason: 'hybrid must redeem its authorization code exactly once',
    );
    expect(
      user?.token.accessToken,
      'FROM-TOKEN-ENDPOINT',
      reason:
          'the final credentials come from the token endpoint; the '
          'front-channel access_token is not the login result',
    );
  });

  test('a response type without a front-channel token is rejected', () async {
    // The guard only required `code`, so loginHybridFlow(responseType:
    // ['code']) ran a plain authorization-code flow: nothing in the front
    // channel, nothing for validateFrontChannelIdToken to check, no error.
    // That is the silent degradation the guard's own message says it exists to
    // prevent, running in the opposite direction -- hybrid quietly becoming a
    // code flow.
    final manager = _TestManager(
      discoveryDocument: _metadata,
      clientCredentials: const OidcClientAuthentication.none(
        clientId: 'client-1',
      ),
      store: OidcMemoryStore(),
      settings: OidcUserManagerSettings(
        redirectUri: Uri.parse('com.example.app://cb'),
      ),
      cannedResponse: (request) async => throw StateError('must not be called'),
    );
    await manager.init();

    // Note the closure: the guard runs BEFORE the first await, so it throws
    // synchronously rather than returning a rejected Future. A caller using
    // `.catchError` would not see it; `try`/`catch` around the call would.
    // Asserting it as a rejected future silently passes for the wrong reason,
    // because the exception escapes expectLater entirely.
    expect(
      () => manager.loginHybridFlow(responseType: const ['code']),
      throwsA(
        isA<OidcException>().having(
          (e) => e.message,
          'message',
          allOf(contains('id_token'), contains('code')),
        ),
      ),
    );
  });
}

late String _capturedNonce;
