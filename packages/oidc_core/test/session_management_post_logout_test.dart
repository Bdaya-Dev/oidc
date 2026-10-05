@TestOn('vm')
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// OpenID Connect Session Management 1.0 (https://openid.net/specs/openid-connect-session-1_0.html).
///
/// The certification suite's `oidcc-client-test-session-management` module
/// (`oidcc-client-rp-session-management-rp-basic` plan) requires at least one
/// `check_session_iframe` postMessage round trip BEFORE the end-session
/// request AND at least one AFTER it, observing the OP report `changed` --
/// completing the handshake `listenToUserSessionIfSupported` started before
/// logout. [OidcUserManagerBase.forgetUser] tears that subscription down the
/// instant `userSubject` goes null, which happens as part of every
/// RP-initiated logout, so without a deliberate final check the "after" probe
/// never happens. These tests cover [OidcUserManagerBase.confirmSessionEndedAtOp],
/// the fix for that gap, via a fake platform (no real browser / iframe).
const _issuer = 'https://op.example.com';
const _checkSessionIframe = 'https://op.example.com/check_session_iframe';

typedef _MonitorCall = ({
  Uri checkSessionIframe,
  OidcMonitorSessionStatusRequest request,
});

/// A manager that records every [monitorSessionStatus] call instead of
/// touching a real browser iframe, and lets a test control both how the
/// end-session request resolves and what the fake OP "answers" each probe.
class _SessionManager extends OidcUserManagerBase {
  _SessionManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
  });

  void seed(OidcUser user) => userSubject.add(user);
  Future<void> saveUserRaw(OidcUser user) => saveUser(user);

  /// `null` mimics a web `samePage` navigation: `oidc_web_core`'s own
  /// `_getResponseUri` returns null synchronously for that mode (the browser
  /// navigates away and the result only surfaces later, from a fresh page
  /// load's `loadStateResult`). A non-null return mimics `popup`/`newPage`,
  /// where the main page never navigates and gets the result back directly.
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSession;

  final List<_MonitorCall> monitorCalls = [];

  /// What the fake OP's check_session_iframe "answers" each probe with.
  /// Defaults to a single `changed` event, matching what a real OP reports
  /// once `removeSessionState` has already run for the ended session.
  Stream<OidcMonitorSessionResult> Function()? monitorStreamFactory;

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
  ) async => onEndSession == null ? null : onEndSession!(request);

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
  }) {
    monitorCalls.add((
      checkSessionIframe: checkSessionIframe,
      request: request,
    ));
    return monitorStreamFactory?.call() ??
        Stream.value(const OidcValidMonitorSessionResult(changed: true));
  }
}

OidcProviderMetadata _metadata({bool withCheckSessionIframe = true}) =>
    OidcProviderMetadata.fromJson({
      'issuer': _issuer,
      'authorization_endpoint': '$_issuer/authorize',
      'token_endpoint': '$_issuer/token',
      'end_session_endpoint': '$_issuer/end-session',
      if (withCheckSessionIframe) 'check_session_iframe': _checkSessionIframe,
    });

Future<OidcUser> _user({String? sessionState}) async {
  final key = JsonWebKey.generate('RS256');
  final idToken =
      (JsonWebSignatureBuilder()
            ..jsonContent = {
              'iss': _issuer,
              'sub': 'user-1',
              'aud': 'client-1',
              'exp':
                  clock
                      .now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
              'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
            }
            ..addRecipient(key, algorithm: 'RS256'))
          .build()
          .toCompactSerialization();
  return OidcUser.fromIdToken(
    token: OidcToken(
      creationTime: clock.now(),
      idToken: idToken,
      accessToken: 'access-token-1',
      refreshToken: 'refresh-token-1',
      tokenType: 'Bearer',
      sessionState: sessionState,
    ),
  );
}

_SessionManager _build({
  bool sessionManagementEnabled = true,
  bool withCheckSessionIframe = true,
  OidcStore? store,
}) {
  final client = MockClient((req) async => http.Response('{}', 404));
  return _SessionManager(
    discoveryDocument: _metadata(
      withCheckSessionIframe: withCheckSessionIframe,
    ),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: store ?? OidcMemoryStore(),
    httpClient: client,
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      postLogoutRedirectUri: Uri.parse('com.example.app://logged-out'),
      sessionManagementSettings: OidcSessionManagementSettings(
        enabled: sessionManagementEnabled,
      ),
    ),
  );
}

void main() {
  group('post-logout session-state confirmation (popup/newPage: '
      'getEndSessionResponse resolves directly)', () {
    test(
      'logout() performs one final check_session probe, using the ending '
      "session's own session_state, before forgetting the user",
      () async {
        final manager = _build();
        await manager.init();
        manager.seed(await _user(sessionState: 'sess-live-1'));
        manager.onEndSession = (request) async =>
            OidcEndSessionResponse.fromJson({'state': request.state});

        await manager.logout();

        // Two calls are expected: `seed()` above already starts the regular
        // monitoring subscription via `listenToUserSessionIfSupported`
        // (satisfying the module's "before" requirement, pre-existing
        // behavior) -- the fix under test is the SECOND call, made by
        // `confirmSessionEndedAtOp` from `handleEndSessionResponse` before
        // `forgetUser()` tears the first one down. Before the fix, only the
        // first call ever happened.
        expect(
          manager.monitorCalls,
          hasLength(2),
          reason:
              'one pre-logout probe (regular monitoring) and one post-logout '
              'confirmation probe are expected; before the fix, '
              "forgetUser()'s userSubject listener tore the monitor down "
              'without ever adding the second, post-logout probe',
        );
        final call = manager.monitorCalls.last;
        expect(call.checkSessionIframe, Uri.parse(_checkSessionIframe));
        expect(call.request.sessionState, 'sess-live-1');
        expect(call.request.clientId, 'client-1');
        expect(manager.currentUser, isNull, reason: 'logout still completes');
      },
    );

    test(
      'no probe is made when session management is disabled (the default)',
      () async {
        final manager = _build(sessionManagementEnabled: false);
        await manager.init();
        manager.seed(await _user(sessionState: 'sess-live-1'));
        manager.onEndSession = (request) async =>
            OidcEndSessionResponse.fromJson({'state': request.state});

        await manager.logout();

        expect(manager.monitorCalls, isEmpty);
        expect(manager.currentUser, isNull);
      },
    );

    test('no probe is made when the OP never issued a session_state', () async {
      final manager = _build();
      await manager.init();
      manager.seed(await _user());
      manager.onEndSession = (request) async =>
          OidcEndSessionResponse.fromJson({'state': request.state});

      await manager.logout();

      expect(manager.monitorCalls, isEmpty);
      expect(manager.currentUser, isNull);
    });

    test(
      'a non-responding OP iframe does not hang logout '
      '(bounded, best-effort probe)',
      () async {
        final manager = _build();
        await manager.init();
        manager.seed(await _user(sessionState: 'sess-live-1'));
        manager.onEndSession = (request) async =>
            OidcEndSessionResponse.fromJson({'state': request.state});
        // Never emits and never completes: simulates a check_session_iframe
        // that loaded but whose OP never answers the postMessage.
        manager.monitorStreamFactory = () =>
            StreamController<OidcMonitorSessionResult>().stream;

        await manager.logout().timeout(const Duration(seconds: 10));

        // Pre-logout (regular monitoring) + post-logout (confirmation) --
        // see the sibling test above for why this is 2, not 1.
        expect(manager.monitorCalls, hasLength(2));
        expect(manager.currentUser, isNull);
      },
    );
  });

  group('post-logout session-state confirmation (web samePage: '
      'getEndSessionResponse resolves later, from a reloaded page)', () {
    test(
      'a resumed end-session response still performs the post-logout probe, '
      "using the persisted session_state -- it cannot read currentUser's "
      'session_state, because this manager never had the user loaded',
      () async {
        final store = OidcMemoryStore();

        // Simulate the page that was alive when logout() was called: it built
        // and persisted the OidcEndSessionState (capturing session_state from
        // its then-current user) and then navigated away -- exactly what
        // oidc_web_core's samePage mode does, and what left a stale cached
        // user + a pending end-session state + response sitting in the store.
        final endSessionState = OidcEndSessionState(
          postLogoutRedirectUri: Uri.parse('com.example.app://logged-out'),
          originalUri: null,
          options: const {},
          sessionState: 'sess-reload-1',
        );
        await store.setStateData(
          state: endSessionState.id,
          stateData: endSessionState.toStorageString(),
        );
        await store.setStateResponseData(
          state: endSessionState.id,
          stateData: Uri.parse(
            'com.example.app://logged-out',
          ).replace(queryParameters: {'state': endSessionState.id}).toString(),
        );

        // The "fresh page load" manager: a brand new instance, seeded only
        // with the stale cached user a real reload would still have on disk
        // (logout()'s forgetUser() on the OLD page never got to run -- the
        // browser navigated away first).
        final manager = _build(store: store);
        await manager.saveUserRaw(await _user(sessionState: 'sess-reload-1'));

        await manager.init();

        expect(
          manager.monitorCalls,
          hasLength(1),
          reason:
              'the resumed end-session response must still probe once, '
              'using the session_state persisted at logout time -- '
              'currentUser is unavailable on this path by construction '
              '(loadStateResult short-circuits loadCachedTokens)',
        );
        expect(
          manager.monitorCalls.single.request.sessionState,
          'sess-reload-1',
        );
        expect(manager.currentUser, isNull);
      },
    );
  });
}
