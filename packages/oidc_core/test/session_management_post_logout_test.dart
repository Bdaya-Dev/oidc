@TestOn('vm')
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// OpenID Connect Session Management 1.0 §3.1 after an RP-initiated logout
/// (RP-Initiated Logout 1.0 §2).
///
/// [OidcUserManagerBase.forgetUser] tears the regular session monitor down the
/// instant `userSubject` goes null, so without a deliberate extra check the RP
/// never asks the OP's `check_session_iframe` about the session it just ended.
/// [OidcUserManagerBase.startEndSessionConfirmation] performs that one check
/// in the background and reports the answer as an
/// [OidcEndSessionConfirmationEvent]; these tests drive it through a fake OP
/// (no real browser / iframe).
const _issuer = 'https://op.example.com';
const _checkSessionIframe = 'https://op.example.com/check_session_iframe';

typedef _MonitorCall = ({
  Uri checkSessionIframe,
  OidcMonitorSessionStatusRequest request,
});

/// A fake OP `check_session_iframe` with the browser's delivery shape
/// (`OidcWebCore.monitorSessionStatus`):
///
/// * every monitor listens on the same `window.onMessage`, so each answer the
///   OP posts back reaches EVERY live monitor, not just the one that asked;
/// * every monitor uses the same iframe id: a monitor that starts replaces
///   the iframe, a monitor that is cancelled removes whichever iframe has
///   that id, and answers are dropped while there is no iframe.
class _FakeOp {
  /// Whether the End-User still has a session at the OP.
  bool sessionAlive = true;

  /// Whether a monitor gets an answer as soon as it starts. When `false`, the
  /// OP stays silent until [reply] is called.
  bool autoReply = true;

  /// What the iframe answers a check with; defaults to the Session
  /// Management 1.0 §3.2 behavior for [sessionAlive].
  OidcMonitorSessionResult Function()? answerOverride;

  final List<StreamController<OidcMonitorSessionResult>> live = [];

  /// Every monitor ever started, in order, with how many answers each one
  /// received.
  final List<StreamController<OidcMonitorSessionResult>> all = [];
  final Map<StreamController<OidcMonitorSessionResult>, int> received = {};

  /// The monitor whose iframe currently holds the shared id, if any.
  StreamController<OidcMonitorSessionResult>? iframeOwner;

  OidcMonitorSessionResult get answer =>
      answerOverride?.call() ??
      OidcValidMonitorSessionResult(changed: !sessionAlive);

  /// The OP posts [answer] back; it reaches every live monitor, if the
  /// shared iframe still exists.
  void reply() {
    if (iframeOwner == null) {
      return;
    }
    final result = answer;
    for (final c in List.of(live)) {
      received[c] = (received[c] ?? 0) + 1;
      c.add(result);
    }
  }

  Stream<OidcMonitorSessionResult> monitor() {
    late final StreamController<OidcMonitorSessionResult> sc;
    sc = StreamController<OidcMonitorSessionResult>(
      onListen: () {
        live.add(sc);
        all.add(sc);
        iframeOwner = sc;
        // The monitor posts `client_id session_state` right away.
        if (autoReply) {
          scheduleMicrotask(reply);
        }
      },
      onCancel: () {
        live.remove(sc);
        // `document.getElementById(iframeId)?.remove()`: removes the shared
        // iframe whoever created it.
        iframeOwner = null;
      },
    );
    return sc.stream;
  }
}

/// A manager that records every [monitorSessionStatus] and authorization
/// request instead of touching a real browser.
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

  /// `null` mimics a web `samePage` navigation; a non-null return mimics
  /// `popup`/`newPage`, where the page gets the result back directly.
  Future<OidcEndSessionResponse?> Function(OidcEndSessionRequest request)?
  onEndSession;

  final List<_MonitorCall> monitorCalls = [];
  final List<OidcAuthorizeRequest> authorizeRequests = [];

  final op = _FakeOp();

  /// Overrides the fake OP for the next [monitorSessionStatus] calls.
  Stream<OidcMonitorSessionResult> Function()? monitorStreamFactory;

  @override
  bool get isWeb => false;

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    authorizeRequests.add(request);
    return null;
  }

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
    return monitorStreamFactory?.call() ?? op.monitor();
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
  Duration endSessionConfirmationTimeout = const Duration(seconds: 10),
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
        endSessionConfirmationTimeout: endSessionConfirmationTimeout,
      ),
    ),
  );
}

/// Builds, inits and signs in a manager whose OP ends its session (and
/// answers the end-session request directly, like `popup`/`newPage`).
Future<_SessionManager> _signedIn({
  bool sessionManagementEnabled = true,
  bool withCheckSessionIframe = true,
  String? sessionState = 'sess-live-1',
  bool opEndsSession = true,
  Duration endSessionConfirmationTimeout = const Duration(seconds: 10),
}) async {
  final manager = _build(
    sessionManagementEnabled: sessionManagementEnabled,
    withCheckSessionIframe: withCheckSessionIframe,
    endSessionConfirmationTimeout: endSessionConfirmationTimeout,
  );
  addTearDown(manager.dispose);
  await manager.init();
  manager.seed(await _user(sessionState: sessionState));
  await pumpEventQueue();
  manager.onEndSession = (request) async {
    if (opEndsSession) {
      manager.op.sessionAlive = false;
    }
    return OidcEndSessionResponse.fromJson({'state': request.state});
  };
  return manager;
}

List<OidcEndSessionConfirmationEvent> _collect(_SessionManager manager) {
  final events = <OidcEndSessionConfirmationEvent>[];
  final sub = manager
      .events()
      .where((e) => e is OidcEndSessionConfirmationEvent)
      .cast<OidcEndSessionConfirmationEvent>()
      .listen(events.add);
  addTearDown(sub.cancel);
  return events;
}

void main() {
  group('post-logout end-session confirmation event', () {
    test('OP logged the session out -> changed, probing the ended '
        "session's own session_state", () async {
      final manager = await _signedIn();
      final events = _collect(manager);

      await manager.logout();
      await pumpEventQueue();

      expect(manager.currentUser, isNull);
      expect(events, hasLength(1));
      expect(events.single.outcome, OidcEndSessionConfirmationOutcome.changed);
      expect(events.single.sessionState, 'sess-live-1');
      expect(
        events.single.result,
        isA<OidcValidMonitorSessionResult>().having(
          (r) => r.changed,
          'changed',
          isTrue,
        ),
      );
      // Regular monitor (started by seed) + the post-logout probe.
      expect(manager.monitorCalls, hasLength(2));
      final probe = manager.monitorCalls.last;
      expect(probe.checkSessionIframe, Uri.parse(_checkSessionIframe));
      expect(probe.request.sessionState, 'sess-live-1');
      expect(probe.request.clientId, 'client-1');
      expect(manager.op.live, isEmpty, reason: 'probe torn down after answer');
    });

    test('OP session still alive (logout did not take) -> unchanged', () async {
      final manager = await _signedIn(opEndsSession: false);
      final events = _collect(manager);

      await manager.logout();
      await pumpEventQueue();

      expect(manager.currentUser, isNull, reason: 'local logout still happens');
      expect(events.map((e) => e.outcome), [
        OidcEndSessionConfirmationOutcome.unchanged,
      ]);
    });

    test('OP iframe answers error -> error', () async {
      final manager = await _signedIn();
      final events = _collect(manager);
      manager.op.answerOverride = () => const OidcErrorMonitorSessionResult();

      await manager.logout();
      await pumpEventQueue();

      expect(events.single.outcome, OidcEndSessionConfirmationOutcome.error);
      expect(events.single.result, isA<OidcErrorMonitorSessionResult>());
    });

    test('OP iframe answers a non-spec value -> error', () async {
      final manager = await _signedIn();
      final events = _collect(manager);
      manager.op.answerOverride = () =>
          const OidcUnknownMonitorSessionResult(data: 'bogus');

      await manager.logout();
      await pumpEventQueue();

      expect(events.single.outcome, OidcEndSessionConfirmationOutcome.error);
      expect(events.single.result, isA<OidcUnknownMonitorSessionResult>());
    });

    test('probe stream errors -> error carrying the error', () async {
      final manager = await _signedIn();
      final events = _collect(manager);
      manager.monitorStreamFactory = () => Stream.error(StateError('boom'));

      await manager.logout();
      await pumpEventQueue();

      expect(manager.currentUser, isNull);
      expect(events.single.outcome, OidcEndSessionConfirmationOutcome.error);
      expect(events.single.error, isA<StateError>());
    });

    test('monitorSessionStatus throwing synchronously does not fail logout '
        '-> error', () async {
      final manager = await _signedIn();
      final events = _collect(manager);
      manager.monitorStreamFactory = () => throw StateError('sync boom');

      await expectLater(manager.logout(), completes);
      await pumpEventQueue();

      expect(manager.currentUser, isNull);
      expect(events.single.outcome, OidcEndSessionConfirmationOutcome.error);
      expect(events.single.error, isA<StateError>());
    });

    test(
      'no answer within endSessionConfirmationTimeout -> timedOut, and the '
      'probe is torn down',
      () async {
        final manager = await _signedIn(
          endSessionConfirmationTimeout: const Duration(milliseconds: 50),
        );
        final events = _collect(manager);
        final silent = StreamController<OidcMonitorSessionResult>();
        manager.monitorStreamFactory = () => silent.stream;

        await manager.logout();
        expect(events, isEmpty, reason: 'logout did not wait for the timeout');

        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          events.single.outcome,
          OidcEndSessionConfirmationOutcome.timedOut,
        );
        expect(events.single.result, isNull);
        expect(silent.hasListener, isFalse);
      },
    );

    test('a platform without session monitoring (empty stream) emits no '
        'event', () async {
      final manager = await _signedIn(
        endSessionConfirmationTimeout: const Duration(milliseconds: 50),
      );
      final events = _collect(manager);
      manager.monitorStreamFactory = Stream.empty;

      await manager.logout();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(manager.currentUser, isNull);
      expect(events, isEmpty);
    });
  });

  group('post-logout probe does not block logout', () {
    test(
      'forgetUser + userChanges(null) happen while the OP has not answered',
      () async {
        final manager = await _signedIn(
          endSessionConfirmationTimeout: const Duration(hours: 1),
        );
        final events = _collect(manager);
        final silent = StreamController<OidcMonitorSessionResult>();
        manager.monitorStreamFactory = () => silent.stream;
        final userChanges = <OidcUser?>[];
        final sub = manager.userChanges().listen(userChanges.add);
        addTearDown(sub.cancel);

        await manager.logout().timeout(const Duration(seconds: 2));
        await pumpEventQueue();

        expect(manager.currentUser, isNull);
        expect(userChanges.last, isNull);
        expect(events, isEmpty);
        expect(silent.hasListener, isTrue, reason: 'probe still waiting');

        await manager.dispose();
        expect(silent.hasListener, isFalse, reason: 'dispose stops the probe');
      },
    );
  });

  group('B-1: the regular monitor must not see the probe answer', () {
    test(
      "an OP answer delivered to every live monitor (the browser's shared "
      'window.onMessage) does not trigger a prompt=none re-authorization '
      'mid-logout',
      () async {
        final manager = await _signedIn();
        final events = _collect(manager);
        expect(
          manager.op.live,
          hasLength(1),
          reason: 'the regular monitor is running before logout',
        );

        await manager.logout();
        await pumpEventQueue();

        expect(
          manager.authorizeRequests,
          isEmpty,
          reason:
              'the regular monitor must be stopped before the probe, '
              "otherwise it reads the probe's `changed` and calls "
              'reAuthorizeUser() (prompt=none)',
        );
        expect(events.map((e) => e.outcome), [
          OidcEndSessionConfirmationOutcome.changed,
        ]);
        expect(manager.op.live, isEmpty);
      },
    );
  });

  group('a new sign-in while the probe is pending', () {
    test(
      'cancels the probe: no event for the old session, and the new '
      "session's monitor keeps its iframe and its answers",
      () async {
        final manager = await _signedIn();
        final events = _collect(manager);
        // The OP does not answer the post-logout probe yet.
        manager.op.autoReply = false;

        await manager.logout();
        await pumpEventQueue();
        expect(manager.op.live, hasLength(1), reason: 'probe pending');

        // The End-User signs in again before the OP answered.
        manager.op
          ..sessionAlive = true
          ..autoReply = true;
        manager.seed(await _user(sessionState: 'sess-live-2'));
        await pumpEventQueue();

        expect(
          events,
          isEmpty,
          reason:
              "the new session's `unchanged` answer must not be reported "
              'as the outcome of the old session',
        );
        final newMonitor = manager.op.all.last;
        expect(manager.monitorCalls.last.request.sessionState, 'sess-live-2');
        expect(manager.op.live, [newMonitor]);
        expect(manager.op.iframeOwner, newMonitor);

        final before = manager.op.received[newMonitor] ?? 0;
        manager.op.reply();
        expect(
          manager.op.received[newMonitor],
          before + 1,
          reason: "the new session's monitor still gets the OP's answers",
        );
      },
    );
  });

  group('gating: apps that did not opt in see no change', () {
    test(
      'session management disabled (the default): no probe, no event, and '
      'no session_state persisted in the end-session state',
      () async {
        final manager = await _signedIn(sessionManagementEnabled: false);
        final events = _collect(manager);
        String? persistedSessionState = 'unset';
        manager.onEndSession = (request) async {
          final raw = await manager.store.getStateData(request.state!);
          persistedSessionState =
              (OidcState.fromStorageString(raw!) as OidcEndSessionState)
                  .sessionState;
          return OidcEndSessionResponse.fromJson({'state': request.state});
        };

        await manager.logout();
        await pumpEventQueue();

        expect(manager.monitorCalls, isEmpty);
        expect(events, isEmpty);
        expect(persistedSessionState, isNull);
        expect(manager.currentUser, isNull);
      },
    );

    test('session_state is persisted when session management is '
        'enabled', () async {
      final manager = await _signedIn();
      String? persistedSessionState;
      manager.onEndSession = (request) async {
        final raw = await manager.store.getStateData(request.state!);
        persistedSessionState =
            (OidcState.fromStorageString(raw!) as OidcEndSessionState)
                .sessionState;
        return OidcEndSessionResponse.fromJson({'state': request.state});
      };

      await manager.logout();

      expect(persistedSessionState, 'sess-live-1');
    });

    test('no check_session_iframe: no probe, no event', () async {
      final manager = await _signedIn(withCheckSessionIframe: false);
      final events = _collect(manager);

      await manager.logout();
      await pumpEventQueue();

      expect(manager.monitorCalls, isEmpty);
      expect(events, isEmpty);
      expect(manager.currentUser, isNull);
    });

    test('no session_state from the OP: no probe, no event', () async {
      final manager = await _signedIn(sessionState: null);
      final events = _collect(manager);

      await manager.logout();
      await pumpEventQueue();

      expect(manager.monitorCalls, isEmpty);
      expect(events, isEmpty);
      expect(manager.currentUser, isNull);
    });
  });

  group('web samePage: the end-session response is resumed on a reloaded '
      'page', () {
    /// The page that called logout() persisted the end-session state (with
    /// the ending session_state) and navigated away; this builds the fresh
    /// page's manager, with only that state, the OP's response and the stale
    /// cached user on disk.
    Future<_SessionManager> resumed({required bool enabled}) async {
      final store = OidcMemoryStore();
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
      final manager = _build(store: store, sessionManagementEnabled: enabled);
      addTearDown(manager.dispose);
      manager.op.sessionAlive = false;
      await manager.saveUserRaw(await _user(sessionState: 'sess-reload-1'));
      return manager;
    }

    test(
      'the resumed response still probes with the persisted session_state '
      'and reports the outcome',
      () async {
        final manager = await resumed(enabled: true);
        final events = _collect(manager);

        await manager.init();
        await pumpEventQueue();

        expect(manager.monitorCalls, hasLength(1));
        expect(
          manager.monitorCalls.single.request.sessionState,
          'sess-reload-1',
        );
        expect(manager.currentUser, isNull);
        expect(
          events.single.outcome,
          OidcEndSessionConfirmationOutcome.changed,
        );
        expect(events.single.sessionState, 'sess-reload-1');
      },
    );

    test(
      'a persisted session_state does not probe when session management is '
      'disabled',
      () async {
        final manager = await resumed(enabled: false);
        final events = _collect(manager);

        await manager.init();
        await pumpEventQueue();

        expect(manager.monitorCalls, isEmpty);
        expect(events, isEmpty);
        expect(manager.currentUser, isNull);
      },
    );
  });
}
