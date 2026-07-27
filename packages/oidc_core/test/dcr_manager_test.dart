@TestOn('vm')
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const _issuerA = 'https://op.example.com';
const _issuerB = 'https://op-b.example.com';
final Uri _wellKnownA = Uri.parse(
  '$_issuerA/.well-known/openid-configuration',
);
final Uri _wellKnownB = Uri.parse(
  '$_issuerB/.well-known/openid-configuration',
);
final JsonWebKey _signingKey = JsonWebKey.generate('RS256');

/// The seed credentials handed to the constructor. Under DCR these are only a
/// pre-registration placeholder: every assertion below checks that the ISSUED
/// identity — never this one — reaches the wire.
const _seedCredentials = OidcClientAuthentication.none(
  clientId: 'seed-client',
);

Map<String, dynamic> _metadataJson({
  String issuer = _issuerA,
  bool includeRegistration = true,
  List<String> algs = const ['RS256'],
}) => {
  'issuer': issuer,
  'authorization_endpoint': '$issuer/authorize',
  'token_endpoint': '$issuer/token',
  'device_authorization_endpoint': '$issuer/device',
  'revocation_endpoint': '$issuer/revoke',
  'introspection_endpoint': '$issuer/introspect',
  'end_session_endpoint': '$issuer/end-session',
  if (includeRegistration) 'registration_endpoint': '$issuer/register',
  // No `jwks_uri`: RS256 tests inject the signing key into the manager
  // keyStore directly, and the HS256 test relies exclusively on the oct key
  // the manager derives from the ISSUED client_secret.
  'id_token_signing_alg_values_supported': algs,
};

OidcProviderMetadata _metadata([Map<String, dynamic>? json]) =>
    OidcProviderMetadata.fromJson(json ?? _metadataJson());

/// One recorded outbound HTTP request.
class _Rec {
  _Rec(this.method, this.url, this.body, this.headers);

  final String method;
  final Uri url;
  final String body;
  final Map<String, String> headers;

  Map<String, String> get form =>
      body.isEmpty ? const {} : Uri.splitQueryString(body);

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;

  /// The `client_secret` this request authenticated with, whichever of the two
  /// RFC 6749 §2.3.1 placements carried it.
  String? get sentClientSecret {
    final posted = form['client_secret'];
    if (posted != null) {
      return posted;
    }
    for (final e in headers.entries) {
      if (e.key.toLowerCase() != 'authorization') {
        continue;
      }
      final value = e.value;
      if (!value.startsWith('Basic ')) {
        continue;
      }
      final decoded = utf8.decode(base64.decode(value.substring(6)));
      return Uri.decodeComponent(decoded.split(':').last);
    }
    return null;
  }
}

extension _RecList on List<_Rec> {
  Iterable<_Rec> to(String suffix) => where((r) => r.url.path.endsWith(suffix));

  int get registrationHits => to('/register').length;

  /// RFC 7592 §2.1 reads (GET `registration_client_uri`).
  Iterable<_Rec> get clientReads =>
      where((r) => r.url.path.contains('/register/'));
}

String _signIdToken({
  required String audience,
  String issuer = _issuerA,
  String subject = 'user-1',
  Duration expiresIn = const Duration(hours: 1),
  JsonWebKey? key,
  String alg = 'RS256',
  String? nonce,
}) {
  final now = clock.now().millisecondsSinceEpoch ~/ 1000;
  return (JsonWebSignatureBuilder()
        ..jsonContent = {
          'iss': issuer,
          'sub': subject,
          'aud': audience,
          'exp': now + expiresIn.inSeconds,
          'iat': now,
          'nonce': ?nonce,
        }
        ..addRecipient(key ?? _signingKey, algorithm: alg))
      .build()
      .toCompactSerialization();
}

/// The `oct` JWK a client_secret maps to (RFC 7518 §3.2), used to sign the
/// HS256 id_tokens the keyStore tests verify.
JsonWebKey _octKey(String secret) => JsonWebKey.fromJson({
  'kty': 'oct',
  'k': base64Url.encode(utf8.encode(secret)).replaceAll('=', ''),
  'alg': 'HS256',
})!;

/// A concrete manager built via the `.lazy` constructor so the tests can drive
/// `init()` end-to-end against a discovery URL.
class _Manager extends OidcUserManagerBase {
  _Manager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    this.completeAuthorizationCodeFlow = false,
    this.isWeb = false,
  }) : super.lazy();

  /// When true, [getAuthorizationResponse] answers with a `code` so the
  /// authorization-code TOKEN EXCHANGE actually runs (that back-channel call is
  /// otherwise unreachable from a test).
  final bool completeAuthorizationCodeFlow;

  /// Every front-channel authorization request the manager built, captured
  /// here because it never reaches the (mocked) network.
  final authorizeRequests = <OidcAuthorizeRequest>[];

  /// Every end-session request the manager built.
  final endSessionRequests = <OidcEndSessionRequest>[];

  /// [OidcUserManagerBase.exchangeToken] is `@protected`, so the RFC 8693 path
  /// can only be driven from inside a subclass.
  Future<OidcTokenResponse> exchangeTokenForTest() => exchangeToken();

  @override
  final bool isWeb;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    authorizeRequests.add(request);
    if (!completeAuthorizationCodeFlow) {
      return null;
    }
    return OidcAuthorizeResponse.fromJson({
      'code': 'auth-code-1',
      'state': request.state,
    });
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    endSessionRequests.add(request);
    return null;
  }

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

/// Default registration body: a never-expiring secret (RFC 7591 §3.2.1 `0`),
/// `client_secret_post` so the issued credentials are observable in the token
/// request's form body.
Map<String, dynamic> _registrationBody({
  String clientId = 'issued-client-1',
  String? clientSecret = 'issued-secret-1',
  String? authMethod = 'client_secret_post',
  Object? clientSecretExpiresAt = 0,
  bool includeManagementMembers = true,
  Map<String, dynamic> extra = const {},
}) => {
  'client_id': clientId,
  'client_secret': ?clientSecret,
  'token_endpoint_auth_method': ?authMethod,
  'client_secret_expires_at': ?clientSecretExpiresAt,
  if (includeManagementMembers) ...{
    'registration_client_uri': '$_issuerA/register/$clientId',
    'registration_access_token': 'rat-$clientId',
  },
  ...extra,
};

/// A MockClient answering discovery / registration / device / token for both
/// issuers, recording every request into [log].
http.Client _client(
  List<_Rec> log, {
  Map<String, dynamic>? metadataA,
  Map<String, dynamic>? metadataB,
  Map<String, dynamic> Function(int hit, Uri url)? registration,
  Map<String, dynamic> Function(int hit, Uri url)? clientRead,

  /// Answers the RFC 7662 introspection endpoint; returning null falls through
  /// to the default `{"active": true}`.
  http.Response? Function(_Rec rec)? introspection,

  /// Records the registration attempt, then fails it the way an offline device
  /// does: the POST never reaches the OP.
  bool offlineRegistration = false,
  int registrationStatus = 200,
  int clientReadStatus = 200,
  String idTokenAlg = 'RS256',
  JsonWebKey? idTokenKey,
  bool includeRefreshToken = false,
  bool echoRequestedMetadata = false,
  Duration accessTokenExpiresIn = const Duration(hours: 1),
  // OIDC Core §3.1.3.7 step 11: the code-flow id_token must echo the `nonce`
  // of the authorization request, which only the manager knows.
  String? Function()? currentNonce,
}) {
  var registrationHits = 0;
  var clientReadHits = 0;
  return MockClient((req) async {
    final rec = _Rec(req.method, req.url, req.body, {...req.headers});
    log.add(rec);
    final path = req.url.path;
    final isB = req.url.host == Uri.parse(_issuerB).host;
    final issuer = isB ? _issuerB : _issuerA;

    if (path.endsWith('openid-configuration')) {
      return http.Response(
        jsonEncode(
          isB
              ? (metadataB ?? _metadataJson(issuer: _issuerB))
              : (metadataA ?? _metadataJson()),
        ),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    // RFC 7592 §2.1 client read at `registration_client_uri`
    // (`/register/<client_id>`), checked before the §3.1 registration endpoint
    // so the two never collide.
    if (path.contains('/register/')) {
      clientReadHits++;
      return http.Response(
        jsonEncode(clientRead?.call(clientReadHits, req.url) ?? const {}),
        clientReadStatus,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/register')) {
      registrationHits++;
      if (offlineRegistration) {
        throw http.ClientException('No internet connection', req.url);
      }
      final body =
          registration?.call(registrationHits, req.url) ??
          _registrationBody(
            clientId: isB ? 'issued-client-b' : 'issued-client-1',
          );
      return http.Response(
        jsonEncode({
          ...body,
          // RFC 7591 §3.2.1: the response echoes the registered client
          // metadata back. Modelling that is what makes an OP-side value
          // (rather than the settings value) observable downstream.
          if (echoRequestedMetadata) ...{
            for (final key in const ['redirect_uris', 'scope'])
              if (rec.json.containsKey(key)) key: rec.json[key],
          },
        }),
        registrationStatus,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/revoke')) {
      return http.Response('', 200);
    }
    if (path.endsWith('/introspect')) {
      return introspection?.call(rec) ??
          http.Response(
            jsonEncode(const {'active': true}),
            200,
            headers: const {'content-type': 'application/json'},
          );
    }
    if (path.endsWith('/device')) {
      return http.Response(
        jsonEncode({
          'device_code': 'device-code',
          'user_code': 'user-code',
          'verification_uri': '$issuer/verify',
          'expires_in': 60,
          'interval': 0,
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    if (path.endsWith('/token')) {
      // The audience is taken from the client_id the manager actually sent, so
      // a token exchange run with the WRONG credentials still yields an
      // id_token the manager rejects rather than silently accepting.
      final audience = rec.form['client_id'] ?? 'unknown-client';
      // RFC 7518 §3.2: an HS*-signed id_token is MAC'd with the client's
      // CURRENT secret. Mirroring that here — keying off the secret this very
      // request authenticated with — is what makes a manager still holding a
      // RETIRED secret unable to verify the response.
      final sentSecret = rec.sentClientSecret;
      final signingKey =
          idTokenKey ??
          (idTokenAlg.startsWith('HS') && sentSecret != null
              ? _octKey(sentSecret)
              : null);
      return http.Response(
        jsonEncode({
          'access_token': 'at-1',
          'token_type': 'Bearer',
          'expires_in': accessTokenExpiresIn.inSeconds,
          if (includeRefreshToken) 'refresh_token': 'rt-1',
          'id_token': _signIdToken(
            audience: audience,
            issuer: issuer,
            key: signingKey,
            alg: idTokenAlg,
            nonce:
                rec.form['grant_type'] ==
                    OidcConstants_GrantType.authorizationCode
                ? currentNonce?.call()
                : null,
          ),
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 404);
  });
}

OidcDynamicClientRegistrationSettings _dcr({
  String? preferredTokenEndpointAuthMethod,
  String? initialAccessToken,
  Map<String, String>? extraHeaders,
  OidcClientRegistrationRequest Function(OidcProviderMetadata)? buildRequest,
  List<String>? grantTypes,
  List<String>? responseTypes,
}) => OidcDynamicClientRegistrationSettings(
  buildRequest:
      buildRequest ??
      (metadata) => OidcClientRegistrationRequest(
        clientName: 'dcr-test-app',
        applicationType: 'native',
      ),
  preferredTokenEndpointAuthMethod: preferredTokenEndpointAuthMethod,
  initialAccessToken: initialAccessToken,
  extraHeaders: extraHeaders,
  grantTypes:
      grantTypes ?? OidcDynamicClientRegistrationSettings.defaultGrantTypes,
  responseTypes:
      responseTypes ??
      OidcDynamicClientRegistrationSettings.defaultResponseTypes,
);

OidcUserManagerSettings _settings({
  OidcDynamicClientRegistrationSettings? dcr,
  OidcInitMode initMode = OidcInitMode.cacheFirst,
  List<String> scope = const ['openid'],
  String redirectUri = 'app://cb',
  Uri? postLogoutRedirectUri,
}) => OidcUserManagerSettings(
  redirectUri: Uri.parse(redirectUri),
  postLogoutRedirectUri: postLogoutRedirectUri,
  initMode: initMode,
  scope: scope,
  userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
  dynamicClientRegistration: dcr,
);

_Manager _manager({
  required OidcStore store,
  required http.Client client,
  OidcUserManagerSettings? settings,
  Uri? discoveryDocumentUri,
  JsonWebKeyStore? keyStore,
  bool completeAuthorizationCodeFlow = false,
  bool isWeb = false,
}) => _Manager.lazy(
  discoveryDocumentUri: discoveryDocumentUri ?? _wellKnownA,
  clientCredentials: _seedCredentials,
  store: store,
  httpClient: client,
  keyStore: keyStore ?? (JsonWebKeyStore()..addKey(_signingKey)),
  settings: settings ?? _settings(dcr: _dcr()),
  completeAuthorizationCodeFlow: completeAuthorizationCodeFlow,
  isWeb: isWeb,
);

/// An [OidcMemoryStore] whose [OidcStoreNamespace.secureTokens] writes always
/// fail — a locked keychain, a full disk, a user that revoked storage access.
class _SecureWriteFailingStore extends OidcMemoryStore {
  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
    String? managerId,
  }) async {
    if (namespace == OidcStoreNamespace.secureTokens) {
      throw StateError('the keychain is locked');
    }
    return super.setMany(namespace, values: values, managerId: managerId);
  }
}

/// An [OidcMemoryStore] whose reads of ONE key fail — an Android
/// `KeyPermanentlyInvalidatedException` after a biometric re-enrolment, an iOS
/// keychain still locked at a background launch. The value is present and
/// intact; it just cannot be read right now.
class _SecureReadFailingStore extends OidcMemoryStore {
  _SecureReadFailingStore(this.failingKey);

  final String failingKey;
  bool failing = true;
  int failedReads = 0;

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) {
    if (failing &&
        namespace == OidcStoreNamespace.secureTokens &&
        keys.contains(failingKey)) {
      failedReads++;
      throw StateError('the keychain is locked');
    }
    return super.getMany(namespace, keys: keys, managerId: managerId);
  }
}

String _registrationKey([String issuer = _issuerA]) =>
    '${OidcUserManagerBase.clientRegistrationKeyPrefix}$issuer';

/// The raw value of the ONE record persisted per issuer.
Future<String?> _storedRecord(OidcStore store, [String issuer = _issuerA]) =>
    store.get(OidcStoreNamespace.secureTokens, key: _registrationKey(issuer));

/// The registration response inside that record, or null when nothing is
/// stored.
Future<Map<String, dynamic>?> _storedRegistration(
  OidcStore store, [
  String issuer = _issuerA,
]) async {
  final raw = await _storedRecord(store, issuer);
  if (raw == null) {
    return null;
  }
  return (jsonDecode(raw) as Map<String, dynamic>)['registration']
      as Map<String, dynamic>?;
}

/// The staleness fingerprint a previous app build running [settings] would have
/// persisted next to its registration.
String _fingerprintFor(
  OidcUserManagerSettings settings, [
  Map<String, dynamic>? metadata,
]) => OidcUserManagerBase.buildClientRegistrationFingerprint(
  settings,
  _metadata(metadata),
);

Future<OidcMemoryStore> _seededStore({
  Map<String, dynamic>? discoveryMetadata,
  Uri? discoveryUri,
  int? discoveryTimestampMs,
  String? tokenJson,
  String? registrationValue,
  String? rawRegistrationValue,
  String? registrationKey,
  OidcUserManagerSettings? registrationSettings,
}) async {
  final store = OidcMemoryStore();
  await store.init();
  if (discoveryMetadata != null) {
    final key = (discoveryUri ?? _wellKnownA).toString();
    await store.setMany(
      OidcStoreNamespace.discoveryDocument,
      values: {
        key: jsonEncode(discoveryMetadata),
        if (discoveryTimestampMs != null)
          '$key${OidcUserManagerBase.discoveryFetchedAtSuffix}':
              discoveryTimestampMs.toString(),
      },
    );
  }
  final regKey = registrationKey ?? _registrationKey();
  final fingerprint = registrationSettings == null
      ? null
      : _fingerprintFor(registrationSettings, discoveryMetadata);
  // ONE key, ONE record: the response and the fingerprint it was issued for
  // travel in the same value, so no two keys can ever disagree.
  final record = registrationValue == null
      ? null
      : jsonEncode({
          'registration': jsonDecode(registrationValue),
          'registered_for': ?fingerprint,
        });
  final secure = <String, String>{
    OidcConstants_Store.currentToken: ?tokenJson,
    regKey: ?(rawRegistrationValue ?? record),
  };
  if (secure.isNotEmpty) {
    await store.setMany(OidcStoreNamespace.secureTokens, values: secure);
  }
  return store;
}

String _tokenJson({
  required String idToken,
  String accessToken = 'at-cached',
  Duration expiresIn = const Duration(hours: 1),
}) => jsonEncode(
  OidcToken(
    creationTime: clock.now().toUtc(),
    idToken: idToken,
    accessToken: accessToken,
    tokenType: 'Bearer',
    expiresIn: expiresIn,
  ).toJson(),
);

Future<Set<String>> _secureKeys(OidcStore store) =>
    store.getAllKeys(OidcStoreNamespace.secureTokens);

void main() {
  group('manager-level Dynamic Client Registration (RFC 7591)', () {
    test(
      'registers exactly once on a cold init and the following token request '
      'carries the ISSUED client_id, not the seed',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(store: store, client: _client(log));

        await manager.init();

        // Exactly one POST to the discovery document's registration_endpoint.
        expect(log.registrationHits, 1);
        final reg = log.to('/register').single;
        expect(reg.method, 'POST');
        expect(reg.url, Uri.parse('$_issuerA/register'));

        final user = await manager.loginDeviceCodeFlow();
        expect(user, isNotNull);

        final tokenReq = log.to('/token').single;
        expect(tokenReq.form['client_id'], 'issued-client-1');
        expect(tokenReq.form['client_id'], isNot('seed-client'));
        await manager.dispose();
      },
    );

    test(
      'a second manager over the SAME store re-uses the persisted registration '
      '(zero further registration requests)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();

        final first = _manager(store: store, client: _client(log));
        await first.init();
        expect(log.registrationHits, 1);
        await first.dispose();

        final second = _manager(store: store, client: _client(log));
        await second.init();

        // The counter is shared across both inits and stayed at 1.
        expect(log.registrationHits, 1);

        final user = await second.loginDeviceCodeFlow();
        expect(user, isNotNull);
        // Reuse, not a silent fallback to the constructor seed.
        expect(log.to('/token').single.form['client_id'], 'issued-client-1');
        await second.dispose();
      },
    );

    test(
      'forgetUser() wipes the tokens but preserves the client registration',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(store: store, client: _client(log));

        await manager.init();
        expect(await manager.loginDeviceCodeFlow(), isNotNull);
        expect(
          await _secureKeys(store),
          contains(OidcConstants_Store.currentToken),
        );

        await manager.forgetUser();

        final keys = await _secureKeys(store);
        // cleanUpStore still wipes what it must...
        expect(keys, isNot(contains(OidcConstants_Store.currentToken)));
        // ...but the app-instance identity survives — as exactly ONE key,
        // carrying the fingerprint it was issued for inside the same value
        // (without which the next launch would treat it as stale and
        // re-register).
        expect(
          keys.where(
            (k) => k.startsWith(
              OidcUserManagerBase.clientRegistrationKeyPrefix,
            ),
          ),
          unorderedEquals([_registrationKey()]),
        );
        await manager.dispose();

        // And a later cold start still re-uses it.
        final next = _manager(store: store, client: _client(log));
        await next.init();
        expect(log.registrationHits, 1);
        await next.dispose();
      },
    );

    test(
      'the ISSUED client_secret reaches the keyStore: an HS256 id_token signed '
      'with it verifies, proving the registration is applied before any '
      'cached token is validated',
      () async {
        final log = <_Rec>[];
        const secret = 'issued-secret-for-hs256-verification-0123456789';
        final store = await _seededStore(
          discoveryMetadata: _metadataJson(algs: const ['HS256']),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(
              audience: 'issued-client-1',
              key: _octKey(secret),
              alg: 'HS256',
            ),
          ),
        );
        final manager = _manager(
          store: store,
          client: _client(
            log,
            metadataA: _metadataJson(algs: const ['HS256']),
            registration: (hit, url) => _registrationBody(clientSecret: secret),
          ),
          settings: _settings(
            dcr: _dcr(),
            initMode: OidcInitMode.blockingValidate,
          ),
          // Deliberately EMPTY: nothing can verify the HS256 MAC unless the
          // manager derives the oct key from the issued client_secret.
          keyStore: JsonWebKeyStore(),
        );
        final surfaced = <OidcUser?>[];
        manager.userChanges().listen(surfaced.add);

        await manager.init();
        // `userChanges()` replays through the subject asynchronously.
        await pumpEventQueue();

        expect(manager.currentUser, isNotNull);
        expect(manager.currentUser!.parsedIdToken.isVerified, isTrue);
        expect(surfaced.whereType<OidcUser>(), isNotEmpty);
        await manager.dispose();
      },
    );

    test(
      'a provider with no registration_endpoint throws a typed OidcException '
      'naming it, and issues no POST at all',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            metadataA: _metadataJson(includeRegistration: false),
          ),
        );

        await expectLater(
          manager.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('registration_endpoint'),
            ),
          ),
        );
        // A typed error, not a TypeError from a null dereference: nothing was
        // POSTed anywhere.
        expect(log.where((r) => r.method == 'POST'), isEmpty);
        await manager.dispose();
      },
    );

    test(
      'a 400 registration error surfaces the RFC 6749 error and persists '
      'nothing',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registrationStatus: 400,
            registration: (hit, url) => {
              'error': 'invalid_client_metadata',
              'error_description': 'redirect_uris is not allowed',
            },
          ),
        );

        await expectLater(
          manager.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.errorResponse?.error,
              'errorResponse.error',
              'invalid_client_metadata',
            ),
          ),
        );
        // Nothing poisoned the cache; a later init retries cleanly.
        expect(
          (await _secureKeys(store)).where(
            (k) => k.startsWith(
              OidcUserManagerBase.clientRegistrationKeyPrefix,
            ),
          ),
          isEmpty,
        );
        await manager.dispose();
      },
    );

    test(
      'a response the manager cannot convert (private_key_jwt) throws and '
      'persists nothing (conversion precedes the store write)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(authMethod: 'private_key_jwt'),
          ),
        );

        await expectLater(manager.init(), throwsA(isA<OidcException>()));
        expect(
          (await _secureKeys(store)).where(
            (k) => k.startsWith(
              OidcUserManagerBase.clientRegistrationKeyPrefix,
            ),
          ),
          isEmpty,
        );
        await manager.dispose();
      },
    );

    test(
      'cacheFirst with a persisted registration completes with ZERO network '
      'requests',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore(
          discoveryMetadata: _metadataJson(),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(audience: 'issued-client-1'),
          ),
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: _settings(dcr: _dcr()),
        );
        final manager = _manager(store: store, client: _client(log));

        await manager.init();

        expect(log, isEmpty);
        expect(manager.clientCredentials.clientId, 'issued-client-1');
        expect(manager.clientRegistration, isNotNull);
        expect(manager.currentUser, isNotNull);
        await manager.dispose();
      },
    );

    test(
      'cacheFirst WITHOUT a persisted registration falls through to the '
      'blocking path instead of running with the seed',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore(
          discoveryMetadata: _metadataJson(),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(audience: 'issued-client-1'),
          ),
        );
        final manager = _manager(store: store, client: _client(log));
        final surfaced = <OidcUser?>[];
        manager.userChanges().listen(surfaced.add);

        await manager.init();
        // `userChanges()` replays through the subject asynchronously.
        await pumpEventQueue();

        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-1');
        // The cached user is still restored (and its `aud` only validates
        // against the ISSUED client_id).
        expect(manager.currentUser, isNotNull);
        expect(surfaced.whereType<OidcUser>(), isNotEmpty);
        await manager.dispose();
      },
    );

    test(
      'an EXPIRED persisted client_secret triggers exactly one '
      're-registration and the new secret is used',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final t0 = DateTime.utc(2026, 1, 1, 12);

        await withClock(Clock.fixed(t0), () async {
          final first = _manager(
            store: store,
            client: _client(
              log,
              registration: (hit, url) => _registrationBody(
                clientSecret: 'secret-1',
                // Expires one hour from t0.
                clientSecretExpiresAt:
                    t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                    1000,
              ),
            ),
          );
          await first.init();
          expect(log.registrationHits, 1);
          await first.dispose();
        });

        await withClock(
          Clock.fixed(t0.add(const Duration(hours: 2))),
          () async {
            final second = _manager(
              store: store,
              client: _client(
                log,
                registration: (hit, url) =>
                    _registrationBody(clientSecret: 'secret-2'),
              ),
            );
            await second.init();

            expect(log.registrationHits, 2);
            expect(await second.loginDeviceCodeFlow(), isNotNull);
            expect(log.to('/token').single.form['client_secret'], 'secret-2');
            await second.dispose();
          },
        );
      },
    );

    test(
      'client_secret_expires_at: 0 (never expires) triggers NO re-registration '
      'even years later',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final t0 = DateTime.utc(2026, 1, 1, 12);

        await withClock(Clock.fixed(t0), () async {
          final first = _manager(store: store, client: _client(log));
          await first.init();
          expect(log.registrationHits, 1);
          await first.dispose();
        });

        await withClock(
          Clock.fixed(t0.add(const Duration(days: 3650))),
          () async {
            final second = _manager(store: store, client: _client(log));
            await second.init();
            // The `_numericDate(0) == epoch` trap would re-register here.
            expect(log.registrationHits, 1);
            expect(second.clientCredentials.clientId, 'issued-client-1');
            await second.dispose();
          },
        );
      },
    );

    test(
      'a persisted registration is scoped to its issuer (no cross-issuer '
      'credential reuse)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();

        final a = _manager(store: store, client: _client(log));
        await a.init();
        expect(log.registrationHits, 1);
        await a.dispose();

        final b = _manager(
          store: store,
          client: _client(log),
          discoveryDocumentUri: _wellKnownB,
        );
        await b.init();

        expect(log.registrationHits, 2);
        expect(
          log.to('/register').last.url,
          Uri.parse('$_issuerB/register'),
        );
        expect(await b.loginDeviceCodeFlow(), isNotNull);
        expect(log.to('/token').single.form['client_id'], 'issued-client-b');
        await b.dispose();
      },
    );

    test(
      'a corrupt persisted registration is a cache MISS and is overwritten in '
      'place, not thrown on',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore(
          rawRegistrationValue: 'this is definitely not json {',
        );
        final manager = _manager(store: store, client: _client(log));

        await manager.init();

        expect(log.registrationHits, 1);
        expect(
          (await _storedRegistration(store))!['client_id'],
          'issued-client-1',
        );
        await manager.dispose();
      },
    );

    test(
      'the manager fills redirect_uris and scope from the settings when the '
      'builder leaves them null',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(),
            scope: const ['openid', 'profile', 'email'],
          ),
        );

        await manager.init();

        final body = log.to('/register').single.json;
        expect(body['redirect_uris'], ['app://cb']);
        expect(body['scope'], 'openid profile email');
        // The builder's own members are untouched.
        expect(body['client_name'], 'dcr-test-app');
        await manager.dispose();
      },
    );

    test(
      'initialAccessToken and extraHeaders reach the registration request '
      '(RFC 7591 §3.1 protected registration)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(
              initialAccessToken: 'iat-123',
              extraHeaders: const {'x-tenant': 'acme'},
            ),
          ),
        );

        await manager.init();

        final reg = log.to('/register').single;
        final headers = {
          for (final e in reg.headers.entries) e.key.toLowerCase(): e.value,
        };
        expect(headers['authorization'], 'Bearer iat-123');
        expect(headers['x-tenant'], 'acme');
        await manager.dispose();
      },
    );

    test(
      'preferredTokenEndpointAuthMethod overrides the method the OP echoed '
      'back',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(authMethod: 'client_secret_basic'),
          ),
          settings: _settings(
            dcr: _dcr(preferredTokenEndpointAuthMethod: 'client_secret_post'),
          ),
        );

        await manager.init();
        expect(await manager.loginDeviceCodeFlow(), isNotNull);

        final tokenReq = log.to('/token').single;
        expect(
          tokenReq.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(tokenReq.form['client_secret'], 'issued-secret-1');
        await manager.dispose();
      },
    );
  });

  group('DCR reviewer findings', () {
    test(
      'finding 0: an OP that issues NO client_secret registers a PUBLIC client '
      '(RFC 7591 §3.2.1: client_secret is OPTIONAL) — init() succeeds, the '
      'registration is PERSISTED, and a relaunch does not orphan a new client',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            // RFC 7591 §3.2.1: no `client_secret`, and (§2) no
            // `token_endpoint_auth_method` either — the OP says nothing, so the
            // client is public.
            registration: (hit, url) => _registrationBody(
              clientSecret: null,
              authMethod: null,
              clientSecretExpiresAt: null,
            ),
          ),
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-1');
        expect(
          manager.clientCredentials.location,
          OidcConstants_ClientAuthenticationMethods.none,
        );
        expect(manager.clientCredentials.clientSecret, isNull);
        // The public client authenticates with client_id only.
        final user = await manager.loginDeviceCodeFlow();
        expect(user, isNotNull);
        final tokenReq = log.to('/token').single;
        expect(tokenReq.form['client_id'], 'issued-client-1');
        expect(tokenReq.form.containsKey('client_secret'), isFalse);
        await manager.dispose();

        // ...and it was PERSISTED, so a relaunch reuses it instead of
        // POSTing a brand-new registration (an orphan at the OP per launch).
        final next = _manager(store: store, client: _client(log));
        await next.init();
        expect(log.registrationHits, 1);
        expect(next.clientCredentials.clientId, 'issued-client-1');
        await next.dispose();
      },
    );

    test(
      'findings 1 + 7: a persisted registration issued for a DIFFERENT '
      'redirectUri is superseded and re-registered with the current one',
      () async {
        final log = <_Rec>[];
        final oldSettings = _settings(dcr: _dcr(), redirectUri: 'app://old-cb');
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: oldSettings,
        );
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-2'),
          ),
          settings: _settings(dcr: _dcr(), redirectUri: 'app://new-cb'),
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(log.to('/register').single.json['redirect_uris'], [
          'app://new-cb',
        ]);
        expect(manager.clientCredentials.clientId, 'issued-client-2');
        await manager.dispose();
      },
    );

    test(
      'findings 1 + 7: a persisted registration issued for a DIFFERENT scope '
      'is superseded and re-registered with the current one',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: _settings(dcr: _dcr()),
        );
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(),
            scope: const ['openid', 'offline_access'],
          ),
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(
          log.to('/register').single.json['scope'],
          'openid offline_access',
        );
        await manager.dispose();
      },
    );

    test(
      'findings 1 + 7: an UNCHANGED settings fingerprint still re-uses the '
      'persisted registration (no spurious re-registration)',
      () async {
        final log = <_Rec>[];
        final settings = _settings(dcr: _dcr());
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: settings,
        );
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: settings,
        );

        await manager.init();

        expect(log.registrationHits, 0);
        expect(manager.clientCredentials.clientId, 'issued-client-1');
        await manager.dispose();
      },
    );

    test(
      'finding 2: the registration declares the grant_types and response_types '
      'the manager actually drives (RFC 7591 §2 defaults to '
      'authorization_code / code only)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(store: store, client: _client(log));

        await manager.init();

        final body = log.to('/register').single.json;
        expect(body['grant_types'], [
          OidcConstants_GrantType.authorizationCode,
          OidcConstants_GrantType.refreshToken,
        ]);
        expect(body['response_types'], [
          OidcConstants_AuthorizationEndpoint_ResponseType.code,
        ]);
        await manager.dispose();
      },
    );

    test(
      'finding 2: an app that drives the device-code flow declares that grant '
      'via the DCR settings, and a later change re-registers',
      () async {
        final log = <_Rec>[];
        final dcrWithDeviceCode = _dcr(
          grantTypes: const [
            OidcConstants_GrantType.authorizationCode,
            OidcConstants_GrantType.refreshToken,
            OidcConstants_GrantType.deviceCode,
          ],
        );
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          // Registered back when the app only did the code flow.
          registrationSettings: _settings(dcr: _dcr()),
        );
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(dcr: dcrWithDeviceCode),
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(
          log.to('/register').single.json['grant_types'],
          contains(OidcConstants_GrantType.deviceCode),
        );
        await manager.dispose();
      },
    );

    test(
      'finding 4: post_logout_redirect_uris is derived from the settings, just '
      'like its sibling redirect_uris',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(),
            postLogoutRedirectUri: Uri.parse('app://post-logout'),
          ),
        );

        await manager.init();

        expect(log.to('/register').single.json['post_logout_redirect_uris'], [
          'app://post-logout',
        ]);
        await manager.dispose();
      },
    );

    test(
      'finding 4: no postLogoutRedirectUri setting means no '
      'post_logout_redirect_uris member at all',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(store: store, client: _client(log));

        await manager.init();

        expect(
          log.to('/register').single.json,
          isNot(contains('post_logout_redirect_uris')),
        );
        await manager.dispose();
      },
    );

    test(
      'finding 5: a scope the OP NARROWED (RFC 7591 §3.2.1) is what later '
      'requests ask for, not what the manager asked to register',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              // Asked for `openid profile email`; the OP granted only two.
              extra: const {'scope': 'openid profile'},
            ),
          ),
          settings: _settings(
            dcr: _dcr(),
            scope: const ['openid', 'profile', 'email'],
          ),
        );

        await manager.init();
        // The manager ASKED for everything the settings configure...
        expect(
          log.to('/register').single.json['scope'],
          'openid profile email',
        );

        // ...and from here on asks only for what the OP granted.
        expect(await manager.loginDeviceCodeFlow(), isNotNull);
        expect(log.to('/device').single.form['scope'], 'openid profile');
        expect(log.to('/token').single.form['scope'], 'openid profile');
        await manager.dispose();
      },
    );

    test(
      'finding 5: a redirect_uri the OP SUBSTITUTED is what the authorization '
      'request carries',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              extra: const {
                'redirect_uris': ['app://op-chosen-cb'],
              },
            ),
          ),
        );

        await manager.init();
        await manager.loginAuthorizationCodeFlow();

        expect(
          manager.authorizeRequests.single.redirectUri,
          Uri.parse('app://op-chosen-cb'),
        );
        await manager.dispose();
      },
    );

    test(
      'finding 5: an OP that echoes the requested values back unchanged leaves '
      'the settings values in force',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              extra: const {
                'scope': 'openid',
                'redirect_uris': ['app://cb'],
              },
            ),
          ),
        );

        await manager.init();
        await manager.loginAuthorizationCodeFlow();

        expect(
          manager.authorizeRequests.single.redirectUri,
          Uri.parse('app://cb'),
        );
        expect(manager.authorizeRequests.single.scope, ['openid']);
        await manager.dispose();
      },
    );

    test(
      'findings 6 + 8: a CACHED registration that parses, has a client_id and '
      'an unexpired secret but cannot be converted is a cache MISS and is '
      'overwritten in place, not thrown out of init()',
      () async {
        final log = <_Rec>[];
        final settings = _settings(dcr: _dcr());
        final store = await _seededStore(
          // Parses cleanly, has client_id, `client_secret_expires_at: 0`
          // (never expires) — every existing cache check passes. Only the
          // conversion to OidcClientAuthentication fails.
          registrationValue: jsonEncode(
            _registrationBody(authMethod: 'private_key_jwt'),
          ),
          registrationSettings: settings,
        );
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-healed'),
          ),
          settings: settings,
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-healed');
        expect(
          (await _storedRegistration(store))!['client_id'],
          'issued-client-healed',
        );
        await manager.dispose();
      },
    );

    test(
      'findings 6 + 8: the same poisoned CACHED entry also self-heals on the '
      'cacheFirst (no-network-first) path',
      () async {
        final log = <_Rec>[];
        final settings = _settings(dcr: _dcr());
        final store = await _seededStore(
          discoveryMetadata: _metadataJson(),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(audience: 'issued-client-healed'),
          ),
          registrationValue: jsonEncode(
            _registrationBody(authMethod: 'private_key_jwt'),
          ),
          registrationSettings: settings,
        );
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-healed'),
          ),
          settings: settings,
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-healed');
        await manager.dispose();
      },
    );
  });

  group('DCR second-round findings', () {
    test(
      'finding 0: a grant_types change made ONLY inside buildRequest is '
      'detected as stale and re-registers',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        OidcUserManagerSettings appVersion(List<String> grantTypes) =>
            _settings(
              dcr: _dcr(
                // The app sets grant_types itself, so the manager's
                // `..grantTypes ??=` default never fires and the value is
                // invisible to a settings-only fingerprint.
                buildRequest: (metadata) => OidcClientRegistrationRequest(
                  clientName: 'dcr-test-app',
                  grantTypes: grantTypes,
                ),
              ),
            );

        final v1 = _manager(
          store: store,
          client: _client(log),
          settings: appVersion(const [
            OidcConstants_GrantType.authorizationCode,
          ]),
        );
        await v1.init();
        expect(log.registrationHits, 1);
        await v1.dispose();

        // v2 of the app adds the refresh grant. The OP-side client is still
        // registered for `authorization_code` only, so reusing it silently
        // breaks the automatic refresh.
        final v2 = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-2'),
          ),
          settings: appVersion(const [
            OidcConstants_GrantType.authorizationCode,
            OidcConstants_GrantType.refreshToken,
          ]),
        );
        await v2.init();

        expect(log.registrationHits, 2);
        expect(log.to('/register').last.json['grant_types'], const [
          OidcConstants_GrantType.authorizationCode,
          OidcConstants_GrantType.refreshToken,
        ]);
        expect(v2.clientCredentials.clientId, 'issued-client-2');
        await v2.dispose();
      },
    );

    test(
      'finding 0: a redirect_uris change made ONLY inside buildRequest '
      're-registers, so the authorize request is not pinned to the STALE '
      'registered uri',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        OidcUserManagerSettings appVersion(String cb) => _settings(
          dcr: _dcr(
            buildRequest: (metadata) => OidcClientRegistrationRequest(
              clientName: 'dcr-test-app',
              redirectUris: [Uri.parse(cb)],
            ),
          ),
        );

        final v1 = _manager(
          store: store,
          client: _client(log, echoRequestedMetadata: true),
          settings: appVersion('app://v1-cb'),
        );
        await v1.init();
        expect(log.registrationHits, 1);
        await v1.dispose();

        final v2 = _manager(
          store: store,
          client: _client(
            log,
            echoRequestedMetadata: true,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-2'),
          ),
          settings: appVersion('app://v2-cb'),
        );
        await v2.init();
        await v2.loginAuthorizationCodeFlow();

        expect(log.registrationHits, 2);
        // Without the re-registration, `effectiveRedirectUri` would return the
        // v1 uri the OP echoed back and every authorization request would hang
        // on a callback the app no longer listens on.
        expect(
          v2.authorizeRequests.single.redirectUri,
          Uri.parse('app://v2-cb'),
        );
        await v2.dispose();
      },
    );

    test(
      'finding 0: volatile and purely descriptive members are EXCLUDED — a '
      'per-call software_statement and a renamed client do NOT re-register',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        var statements = 0;
        var builderCalls = 0;
        OidcUserManagerSettings appVersion(String clientName) => _settings(
          dcr: _dcr(
            buildRequest: (metadata) {
              builderCalls++;
              return OidcClientRegistrationRequest(
                clientName: clientName,
                // RFC 7591 §2.3: a freshly signed assertion per call. Folding
                // it into the fingerprint would re-register on every launch.
                softwareStatement: 'signed-statement-${statements++}',
              );
            },
          ),
        );

        final v1 = _manager(
          store: store,
          client: _client(log),
          settings: appVersion('App v1'),
        );
        await v1.init();
        expect(log.registrationHits, 1);
        await v1.dispose();

        final v2 = _manager(
          store: store,
          client: _client(log),
          settings: appVersion('App v2 (renamed)'),
        );
        await v2.init();

        expect(log.registrationHits, 1);
        expect(v2.clientCredentials.clientId, 'issued-client-1');
        // One build per init: the staleness check must not pay for (or
        // re-sign) a second assertion.
        expect(builderCalls, 2);
        await v2.dispose();
      },
    );

    test(
      'finding 4: logout() sends the REGISTERED post_logout_redirect_uri when '
      'the OP substituted its own (RFC 7591 §3.2.1)',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              extra: const {
                'post_logout_redirect_uris': ['app://op-normalised-logout'],
              },
            ),
          ),
          settings: _settings(
            dcr: _dcr(),
            postLogoutRedirectUri: Uri.parse('app://settings-logout'),
          ),
        );

        await manager.init();
        expect(await manager.loginDeviceCodeFlow(), isNotNull);
        await manager.logout();

        // OpenID Connect RP-Initiated Logout 1.0 §3: the value MUST have been
        // registered, so an OP that normalises it rejects the settings value.
        expect(
          manager.endSessionRequests.single.postLogoutRedirectUri,
          Uri.parse('app://op-normalised-logout'),
        );
        await manager.dispose();
      },
    );

    test(
      'finding 4: an OP that registered the settings value leaves it in force, '
      'and an explicit override still wins',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              extra: const {
                'post_logout_redirect_uris': [
                  'app://other-logout',
                  'app://settings-logout',
                ],
              },
            ),
          ),
          settings: _settings(
            dcr: _dcr(),
            postLogoutRedirectUri: Uri.parse('app://settings-logout'),
          ),
        );

        await manager.init();
        expect(await manager.loginDeviceCodeFlow(), isNotNull);
        await manager.logout();
        expect(
          manager.endSessionRequests.single.postLogoutRedirectUri,
          Uri.parse('app://settings-logout'),
        );

        expect(await manager.loginDeviceCodeFlow(), isNotNull);
        await manager.logout(
          postLogoutRedirectUriOverride: Uri.parse('app://explicit'),
        );
        expect(
          manager.endSessionRequests.last.postLogoutRedirectUri,
          Uri.parse('app://explicit'),
        );
        await manager.dispose();
      },
    );
  });

  group('DCR third-round findings', () {
    test(
      'finding A: a re-registration that cannot reach the OP leaves the '
      'PREVIOUS registration intact and usable instead of destroying it',
      () async {
        final offlineLog = <_Rec>[];
        final onlineLog = <_Rec>[];
        // Registered back when the app asked for `openid` alone.
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: _settings(dcr: _dcr()),
        );
        // The app update widens the scope, so the persisted registration is
        // stale and the manager wants to replace it...
        final widened = _settings(
          dcr: _dcr(),
          scope: const ['openid', 'offline_access'],
        );

        final offline = _manager(
          store: store,
          // ...but the device is offline, so the replacement never arrives.
          client: _client(offlineLog, offlineRegistration: true),
          settings: widened,
        );
        await offline.init();

        expect(offlineLog.registrationHits, 1);
        // The client that DID work is still the one being used.
        expect(offline.clientCredentials.clientId, 'issued-client-1');
        // And it is still on disk — including the RFC 7592 §3
        // registration_access_token, the only credential that can ever manage
        // this OP-side client again.
        expect(
          (await _storedRegistration(store))!.containsKey(
            'registration_access_token',
          ),
          isTrue,
        );
        await offline.dispose();

        // Once the network is back the stale entry is replaced normally.
        final online = _manager(
          store: store,
          client: _client(
            onlineLog,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-2'),
          ),
          settings: widened,
        );
        await online.init();
        expect(onlineLog.registrationHits, 1);
        expect(online.clientCredentials.clientId, 'issued-client-2');
        expect(
          (await _storedRegistration(store))!['client_id'],
          'issued-client-2',
        );
        await online.dispose();
      },
    );

    test(
      'finding A: the same survival holds on the cacheFirst path, whose '
      'fallback is the persisted registration itself',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore(
          discoveryMetadata: _metadataJson(),
          discoveryTimestampMs: clock.now().millisecondsSinceEpoch,
          tokenJson: _tokenJson(
            idToken: _signIdToken(audience: 'issued-client-1'),
          ),
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: _settings(dcr: _dcr()),
        );
        final manager = _manager(
          store: store,
          client: _client(log, offlineRegistration: true),
          settings: _settings(
            dcr: _dcr(),
            scope: const ['openid', 'offline_access'],
          ),
        );

        await manager.init();

        expect(manager.clientCredentials.clientId, 'issued-client-1');
        expect(
          await store.get(
            OidcStoreNamespace.secureTokens,
            key: _registrationKey(),
          ),
          isNotNull,
        );
        await manager.dispose();
      },
    );

    test(
      'finding C: on web the client registers as PUBLIC — '
      'token_endpoint_auth_method `none`, no secret anywhere',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) =>
                _registrationBody(clientSecret: null, authMethod: null),
          ),
          isWeb: true,
        );

        await manager.init();

        // RFC 7591 §2: an omitted `token_endpoint_auth_method` means
        // `client_secret_basic`, i.e. a CONFIDENTIAL client — never correct
        // for a browser app.
        expect(
          log.to('/register').single.json['token_endpoint_auth_method'],
          'none',
        );
        expect(manager.clientCredentials.clientSecret, isNull);
        final stored = await store.get(
          OidcStoreNamespace.secureTokens,
          key: _registrationKey(),
        );
        expect(
          jsonDecode(stored!) as Map<String, dynamic>,
          isNot(contains('client_secret')),
        );
        await manager.dispose();
      },
    );

    test(
      'finding C: an OP that issues a client_secret to a web client fails '
      'LOUDLY and persists nothing',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          // The default body issues `issued-secret-1`.
          client: _client(log),
          isWeb: true,
        );

        await expectLater(
          manager.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              allOf(contains('client_secret'), contains('web')),
            ),
          ),
        );
        expect(
          (await _secureKeys(store)).where(
            (k) =>
                k.startsWith(OidcUserManagerBase.clientRegistrationKeyPrefix),
          ),
          isEmpty,
        );
        await manager.dispose();
      },
    );

    test(
      'finding C: a PERSISTED registration carrying a client_secret is not '
      'replayed on web — it is dropped and replaced by a public one',
      () async {
        final log = <_Rec>[];
        final settings = _settings(dcr: _dcr());
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: settings,
        );
        final manager = _manager(
          store: store,
          client: _client(
            log,
            registration: (hit, url) => _registrationBody(
              clientId: 'issued-client-web',
              clientSecret: null,
              authMethod: null,
            ),
          ),
          settings: settings,
          isWeb: true,
        );

        await manager.init();

        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-web');
        expect(manager.clientCredentials.clientSecret, isNull);
        final stored = await store.get(
          OidcStoreNamespace.secureTokens,
          key: _registrationKey(),
        );
        expect(stored, isNot(contains('issued-secret-1')));
        await manager.dispose();
      },
    );

    test(
      'finding D: a registration whose PERSIST fails is not applied, and the '
      'failure is surfaced instead of silently minting a client per launch',
      () async {
        final log = <_Rec>[];
        final store = _SecureWriteFailingStore();
        await store.init();
        final manager = _manager(store: store, client: _client(log));

        await expectLater(
          manager.init(),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('persist'),
            ),
          ),
        );

        expect(log.registrationHits, 1);
        // Nothing was swapped in: the manager never pretends to be a client
        // whose identity it could not write down.
        expect(manager.clientRegistration, isNull);
        expect(manager.clientCredentials.clientId, 'seed-client');
        await manager.dispose();
      },
    );
  });

  group('DCR non-goals: the RFC 7592 automation the manager does NOT drive', () {
    test(
      'a client_secret that expires MID-SESSION is not chased: ZERO RFC 7592 '
      '§2.1 reads, and the call keeps presenting the credential the OP issued',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final t0 = DateTime.utc(2026, 1, 1, 12);
        var now = t0;

        await withClock(Clock(() => now), () async {
          final manager = _manager(
            store: store,
            client: _client(
              log,
              accessTokenExpiresIn: const Duration(days: 30),
              registration: (hit, url) => _registrationBody(
                clientSecret: 'secret-1',
                clientSecretExpiresAt:
                    t0.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                    1000,
              ),
            ),
          );
          await manager.init();
          expect(await manager.loginDeviceCodeFlow(), isNotNull);

          now = t0.add(const Duration(hours: 2));
          await manager.introspectToken(token: 'at-1');

          // RFC 7592 App. A.1: "the authorization server decides the frequency
          // of the credential rotation and not the client". Nothing here reads
          // registration_client_uri, and nothing re-registers.
          expect(log.clientReads, isEmpty);
          expect(log.registrationHits, 1);
          expect(log.to('/introspect').single.sentClientSecret, 'secret-1');
          await manager.dispose();
        });
      },
    );

    test(
      'an `invalid_client` from the OP is surfaced untouched: no '
      're-registration, no retry, and the record survives for the app to '
      'manage',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(
            log,
            // RFC 6749 §5.2. The manager cannot tell "you are not this client"
            // from "you authenticated wrongly" from "that method is not
            // supported", and OpenID Connect Registration §4.4 forbids the 404
            // that would disambiguate it — so it does not guess.
            introspection: (rec) => http.Response(
              jsonEncode(const {'error': 'invalid_client'}),
              401,
              headers: const {'content-type': 'application/json'},
            ),
          ),
        );
        await manager.init();
        expect(log.registrationHits, 1);

        await expectLater(
          manager.introspectToken(token: 'at-1'),
          throwsA(isA<OidcException>()),
        );

        // Still ONE POST — the one init made. The rejection minted nothing.
        expect(log.registrationHits, 1);
        expect(manager.clientCredentials.clientId, 'issued-client-1');
        // And the record is intact, so the app can drive RFC 7592 against it
        // (or forget it) rather than being handed an orphan.
        expect(
          (await _storedRegistration(store))!['registration_access_token'],
          'rat-issued-client-1',
        );
        await manager.dispose();
      },
    );

    test(
      'forgetClientRegistration() is the documented recovery: it deletes the '
      'record so the NEXT launch registers afresh, and leaves the tokens alone',
      () async {
        final first = <_Rec>[];
        final store = await _seededStore(
          tokenJson: _tokenJson(
            idToken: _signIdToken(audience: 'issued-client-1'),
          ),
        );
        final manager = _manager(store: store, client: _client(first));
        await manager.init();
        expect(first.registrationHits, 1);

        await manager.forgetClientRegistration();

        expect(await _storedRecord(store), isNull);
        // Only the registration went; nothing else in secureTokens was touched.
        expect(
          await _secureKeys(store),
          contains(OidcConstants_Store.currentToken),
        );
        await manager.dispose();

        final second = <_Rec>[];
        final next = _manager(
          store: store,
          client: _client(
            second,
            registration: (hit, url) =>
                _registrationBody(clientId: 'issued-client-2'),
          ),
        );
        await next.init();
        expect(second.registrationHits, 1);
        expect(next.clientCredentials.clientId, 'issued-client-2');
        await next.dispose();
      },
    );

    test(
      'an UNREADABLE store is not an empty store: the read failure is a cache '
      'miss and the existing record is left exactly as it was',
      () async {
        final log = <_Rec>[];
        final store = _SecureReadFailingStore(_registrationKey());
        await store.init();
        final settings = _settings(dcr: _dcr());
        final seeded = jsonEncode({
          'registration': _registrationBody(),
          'registered_for': _fingerprintFor(settings),
        });
        await store.setMany(
          OidcStoreNamespace.secureTokens,
          values: {_registrationKey(): seeded},
        );

        // The registration the manager falls back to attempting cannot be
        // completed either, so nothing overwrites the record — which is the
        // only way to observe whether the read failure DELETED it.
        final manager = _manager(
          store: store,
          client: _client(log, offlineRegistration: true),
          settings: settings,
        );
        await expectLater(manager.init(), throwsA(isA<Object>()));

        expect(store.failedReads, 1);
        expect(log.registrationHits, 1);
        await manager.dispose();

        // Intact, byte for byte. A store that cannot be read must never be
        // answered by destroying the only copy of the client_id and of the RFC
        // 7592 §3 registration_access_token: that is a permanent orphan traded
        // for a condition that clears on its own.
        store.failing = false;
        expect(await _storedRecord(store), seeded);
      },
    );
  });

  group('DCR grafts: RFC 8252 §7.3 loopback, and a DERIVED application_type', () {
    test(
      'RFC 8252 §7.3: a loopback redirect whose PORT moved since the last '
      'launch is the SAME registration — no re-registration, and the '
      'authorization request keeps the LIVE port',
      () async {
        final log = <_Rec>[];
        final issued = _settings(
          dcr: _dcr(),
          redirectUri: 'http://127.0.0.1:51234/cb',
        );
        final store = await _seededStore(
          registrationValue: jsonEncode(
            _registrationBody(
              extra: const {
                'redirect_uris': ['http://127.0.0.1:51234/cb'],
              },
            ),
          ),
          registrationSettings: issued,
        );
        // Next launch, the loopback listener bound a different ephemeral port.
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(),
            redirectUri: 'http://127.0.0.1:8912/cb',
          ),
        );

        await manager.init();
        await manager.loginAuthorizationCodeFlow();

        // Without §7.3 normalization this is one new OP-side client per launch,
        // forever...
        expect(log.registrationHits, 0);
        // ...and the request would be pinned to a port nothing is listening on.
        expect(
          manager.authorizeRequests.single.redirectUri,
          Uri.parse('http://127.0.0.1:8912/cb'),
        );
        await manager.dispose();
      },
    );

    test(
      'the §7.3 carve-out is ONLY for the loopback port: a port change on a '
      'non-loopback https redirect still re-registers',
      () async {
        final log = <_Rec>[];
        final issued = _settings(
          dcr: _dcr(),
          redirectUri: 'https://app.example.com:8443/cb',
        );
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: issued,
        );
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(),
            redirectUri: 'https://app.example.com:9443/cb',
          ),
        );

        await manager.init();

        expect(log.registrationHits, 1);
        await manager.dispose();
      },
    );

    test(
      'application_type is DERIVED from the redirect uris: a custom scheme and '
      'a loopback http uri both register as `native` (OIDC Reg §2)',
      () async {
        for (final redirectUri in const [
          'app://cb',
          'http://127.0.0.1:8912/cb',
          'http://localhost:8912/cb',
        ]) {
          final log = <_Rec>[];
          final store = await _seededStore();
          final manager = _manager(
            store: store,
            client: _client(log),
            settings: _settings(
              dcr: _dcr(
                buildRequest: (metadata) =>
                    OidcClientRegistrationRequest(clientName: 'dcr-test-app'),
              ),
              redirectUri: redirectUri,
            ),
          );
          await manager.init();
          expect(
            log.to('/register').single.json['application_type'],
            OidcConstants_ApplicationType.native,
            reason: redirectUri,
          );
          await manager.dispose();
        }
      },
    );

    test(
      'an https App Link redirect registers as `web`, not `native` — OIDC Reg '
      '§2 makes that a client-side rule, so it follows the uris and not the '
      'host platform',
      () async {
        final log = <_Rec>[];
        final store = await _seededStore();
        final manager = _manager(
          store: store,
          client: _client(log),
          settings: _settings(
            dcr: _dcr(
              buildRequest: (metadata) =>
                  OidcClientRegistrationRequest(clientName: 'dcr-test-app'),
            ),
            redirectUri: 'https://app.example.com/callback',
          ),
        );

        await manager.init();

        expect(
          log.to('/register').single.json['application_type'],
          OidcConstants_ApplicationType.web,
        );
        await manager.dispose();
      },
    );

    test(
      'an explicit application_type from buildRequest wins, and CHANGING it '
      're-registers (it is part of what the client was issued for)',
      () async {
        OidcUserManagerSettings settingsWith(String applicationType) =>
            _settings(
              dcr: _dcr(
                buildRequest: (metadata) => OidcClientRegistrationRequest(
                  clientName: 'dcr-test-app',
                  applicationType: applicationType,
                ),
              ),
              // `app://cb` is a uri the derivation would call `native`, so only
              // the explicit value can produce `web`.
            );

        final log = <_Rec>[];
        final store = await _seededStore(
          registrationValue: jsonEncode(_registrationBody()),
          registrationSettings: settingsWith(
            OidcConstants_ApplicationType.native,
          ),
        );

        // Same value: the record still matches, nothing is registered.
        final same = _manager(
          store: store,
          client: _client(log),
          settings: settingsWith(OidcConstants_ApplicationType.native),
        );
        await same.init();
        expect(log.registrationHits, 0);
        await same.dispose();

        // Changed value: the OP-side client is registered for something this
        // build no longer asks for.
        final changed = _manager(
          store: store,
          client: _client(log),
          settings: settingsWith(OidcConstants_ApplicationType.web),
        );
        await changed.init();
        expect(log.registrationHits, 1);
        expect(
          log.to('/register').single.json['application_type'],
          OidcConstants_ApplicationType.web,
        );
        await changed.dispose();
      },
    );
  });

  group('the key the record is forgotten by is the key it was written by', () {
    test(
      'forgetClientRegistration() BEFORE init() removes the record that a '
      'previous launch wrote',
      () async {
        // The write path always runs with the discovery document loaded, so it
        // keys on `issuer`. forgetClientRegistration() is the app's documented
        // recovery and is exactly the call made when init() is failing, i.e.
        // with no discovery document -- where the fallback used to yield
        // `https://op/.well-known/openid-configuration` and remove a key that
        // was never written, reporting success while the record survived.
        final store = await _seededStore();
        final first = <_Rec>[];
        final wrote = _manager(store: store, client: _client(first));
        await wrote.init();
        expect(first.registrationHits, 1);
        expect(await _storedRecord(store), isNotNull);
        await wrote.dispose();

        final fresh = _manager(store: store, client: _client(<_Rec>[]));
        await fresh.forgetClientRegistration();

        expect(await _storedRecord(store), isNull);
        await fresh.dispose();
      },
    );
  });

  group('web never persists RFC 7592 bearer credentials', () {
    test('the management members are redacted from the stored record', () {
      const json = {
        'client_id': 'issued-client-1',
        'token_endpoint_auth_method': 'none',
        'redirect_uris': ['https://app.example/cb'],
        'registration_access_token': 'rat-issued-client-1',
        'registration_client_uri': 'https://op.example.com/register/client-1',
      };
      final response = OidcClientRegistrationResponse.fromJson(json);

      final onWeb = jsonDecode(
        OidcUserManagerBase.encodeClientRegistrationRecord(
          response,
          fingerprint: 'fp',
          redactManagementCredentials: true,
        ),
      );
      final stored =
          (onWeb as Map<String, dynamic>)['registration']
              as Map<String, Object?>;
      expect(stored.containsKey('registration_access_token'), isFalse);
      expect(stored.containsKey('registration_client_uri'), isFalse);
      // Only the credentials go; the protocol values the manager runs as stay.
      expect(stored['client_id'], 'issued-client-1');
      expect(stored['token_endpoint_auth_method'], 'none');

      final native = jsonDecode(
        OidcUserManagerBase.encodeClientRegistrationRecord(
          response,
          fingerprint: 'fp',
        ),
      );
      final kept =
          (native as Map<String, dynamic>)['registration']
              as Map<String, Object?>;
      expect(kept['registration_access_token'], 'rat-issued-client-1');
    });
  });
}
