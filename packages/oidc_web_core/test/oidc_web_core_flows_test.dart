@TestOn('js')
library;

// ignore_for_file: prefer_const_constructors

import 'dart:js_interop';

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Coverage notes -- regions in lib/src/oidc_web_core.dart that this suite
// intentionally does NOT cover because they can't be exercised
// deterministically in a headless, same-origin package:test harness:
//
//  * The COOP fall-through in the newPage/popup window-closed detector (the
//    `!canDetectPreparedWindowClosure` branch that cancels the poll instead of
//    erroring) only fires when a WindowProxy reports `closed == true` before it
//    was ever observed open -- a Cross-Origin-Opener-Policy severance a
//    same-origin test window never reproduces. Its counterpart (observe open,
//    then close -> window_closed OidcException) IS covered below.
//  * `sendCheckSession`'s `catch` (postMessage to the OP iframe throwing) and
//    its `contentWindow == null` early return: a same-origin, successfully
//    loaded iframe never throws there and always exposes a contentWindow.
//  * The `c.isCompleted` / `streamController == null` re-entrancy guards are
//    defensive: the BroadcastChannel is torn down the instant the flow
//    completes, and the front-channel handler is only attached after its
//    controller is assigned, so neither guard is reachable via the public API.
//
// In lib/src/oidc_web_crypto.dart the still-uncovered lines are the cross-tab
// `add`-race ConstraintError reread path and the WebCrypto/IndexedDB fault
// handlers (encrypt catch, IDB open/request onerror) -- all of which need a
// second browsing context or an injected API fault a single secure-localhost
// context can't produce.

/// A string that `Uri.tryParse` rejects (empty scheme before ':'), used to
/// exercise the "message wasn't a parseable Uri" branches. Guarded at the
/// point of use with an `expect(..., isNull)` so a future SDK behavior change
/// fails loudly here rather than as an uncaught callback error.
const _unparseable = ':::not a uri';

/// Metadata whose only relevant endpoint is `authorization_endpoint`.
OidcProviderMetadata _authMetadata() => OidcProviderMetadata.fromJson(const {
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

OidcProviderMetadata _endSessionMetadata() =>
    OidcProviderMetadata.fromJson(const {
      'issuer': 'https://op.example.com',
      'end_session_endpoint': 'https://op.example.com/logout',
    });

OidcAuthorizeRequest _authRequest({String? state, List<String>? prompt}) =>
    OidcAuthorizeRequest(
      responseType: const ['code'],
      clientId: 'client-1',
      redirectUri: Uri.parse('https://app.example.com/cb'),
      scope: const ['openid'],
      state: state,
      prompt: prompt,
    );

void main() {
  const core = OidcWebCore();

  group('getAuthorizationResponse — hiddenIFrame', () {
    test('resolves the OidcAuthorizeResponse posted on the BroadcastChannel, '
        'ignoring a non-string, an unparseable, and a state-mismatch message '
        'that arrive first', () async {
      expect(Uri.tryParse(_unparseable), isNull);

      const channelName = 'flows-hidden-authorize-ok';
      final options = OidcPlatformSpecificOptions_Web(
        navigationMode:
            OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
        broadcastChannel: channelName,
      );

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-123', prompt: const ['none']),
        options,
        const {},
      );
      // Let `_getResponseUri` attach `channel.onmessage` before we post.
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // `close` is an external interop member and can't be torn off.
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());

      channel
        // Non-string -> rejected at the `isA<JSString>` guard.
        ..postMessage(42.toJS)
        // Parseable as a string but not a Uri -> rejected at `Uri.tryParse`.
        ..postMessage(_unparseable.toJS)
        // Right shape, wrong state -> rejected at the state-mismatch check.
        ..postMessage('https://app.example.com/cb?state=WRONG&code=nope'.toJS)
        // The real one.
        ..postMessage(
          'https://app.example.com/cb?state=st-123&code=the-code'.toJS,
        );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'the-code');
      expect(resp.state, 'st-123');
    });

    test(
      'returns null when the hidden iframe times out with no response',
      () async {
        // Pre-seed a stale element under the redirect-iframe id so
        // `_createHiddenIframe` takes its "remove the previous one" branch.
        web.document.body!.append(
          web.document.createElement('iframe')..id = 'oidc-redirect-iframe',
        );

        final options = OidcPlatformSpecificOptions_Web(
          navigationMode:
              OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
          broadcastChannel: 'flows-hidden-authorize-timeout',
          hiddenIframeTimeout: const Duration(milliseconds: 100),
        );

        final resp = await core.getAuthorizationResponse(
          _authMetadata(),
          _authRequest(state: 'st-timeout', prompt: const ['none']),
          options,
          const {},
        );
        expect(resp, isNull);
      },
    );

    test('throws when hiddenIFrame is used without a "none" prompt', () async {
      final options = OidcPlatformSpecificOptions_Web(
        navigationMode:
            OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
        broadcastChannel: 'flows-hidden-authorize-badprompt',
      );
      await expectLater(
        core.getAuthorizationResponse(
          _authMetadata(),
          _authRequest(state: 'st', prompt: const ['login']),
          options,
          const {},
        ),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('getAuthorizationResponse — newPage/popup preparation', () {
    test('throws when the window was not prepared first', () async {
      // The default navigation mode is newPage, which (like popup) requires a
      // prepared window; an empty preparation payload must throw.
      final options = OidcPlatformSpecificOptions_Web(
        broadcastChannel: 'flows-newpage-unprepared',
      );
      await expectLater(
        core.getAuthorizationResponse(
          _authMetadata(),
          _authRequest(state: 'st'),
          options,
          const {},
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('prepareForRedirectFlow opens (or attempts to open) a window for '
        'popup and newPage, and is a no-op for samePage', () {
      // The popup branch also runs `_calculatePopupOptions`. Both window.open
      // calls execute regardless of whether the headless harness returns a
      // real WindowProxy or null (popups are blocked without a user gesture).
      final popupPrep = core.prepareForRedirectFlow(
        const OidcPlatformSpecificOptions_Web(
          navigationMode: OidcPlatformSpecificOptions_Web_NavigationMode.popup,
        ),
      );
      // Default navigation mode is newPage.
      final newPagePrep = core.prepareForRedirectFlow(
        const OidcPlatformSpecificOptions_Web(),
      );
      final samePagePrep = core.prepareForRedirectFlow(
        const OidcPlatformSpecificOptions_Web(
          navigationMode:
              OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
        ),
      );

      expect(samePagePrep, isEmpty);
      expect(popupPrep, anyOf(isEmpty, contains('web_window')));
      expect(newPagePrep, anyOf(isEmpty, contains('web_window')));

      // Close any windows that actually opened so they don't linger.
      for (final prep in [popupPrep, newPagePrep]) {
        final win = prep['web_window'] as web.Window?;
        if (win != null && !win.closed) {
          win.close();
        }
      }
    });

    test('full popup/newPage flow via a prepared window (skips when the '
        'headless harness blocks window.open)', () async {
      const channelName = 'flows-newpage-full';
      // Default navigation mode is newPage.
      final options = OidcPlatformSpecificOptions_Web(
        broadcastChannel: channelName,
      );
      final preparation = core.prepareForRedirectFlow(options);
      final win = preparation['web_window'] as web.Window?;
      if (win == null) {
        // Observed in headless Chrome/Firefox under package:test: window.open
        // returns null because there is no user gesture, so the prepared-window
        // happy path (location.replace + window-closed poll + close) cannot be
        // exercised here. The unprepared-throw and preparation branches above
        // still cover the surrounding code.
        markTestSkipped('window.open returned null (no user gesture).');
        return;
      }
      addTearDown(() {
        if (!win.closed) win.close();
      });

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'popup-state'),
        options,
        preparation,
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      channel.postMessage(
        'https://app.example.com/cb?state=popup-state&code=popup-code'.toJS,
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'popup-code');
      expect(win.closed, isTrue);
    });

    test('closing the prepared window before the flow completes surfaces an '
        'OidcException with reason window_closed (skips when window.open is '
        'blocked)', () async {
      const channelName = 'flows-window-closed';
      // Default navigation mode is newPage.
      final options = OidcPlatformSpecificOptions_Web(
        broadcastChannel: channelName,
      );
      final preparation = core.prepareForRedirectFlow(options);
      final win = preparation['web_window'] as web.Window?;
      if (win == null) {
        markTestSkipped('window.open returned null (no user gesture).');
        return;
      }

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'closed-state'),
        options,
        preparation,
      );
      // The detector polls every 250ms; it only treats `closed == true` as a
      // real closure after it has first observed the window OPEN (to survive a
      // COOP-severed WindowProxy). Wait past one poll so that observation is
      // made, then close the window ourselves.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!win.closed) win.close();

      await expectLater(
        future,
        throwsA(
          isA<OidcException>().having(
            (e) => e.extra['reason'],
            'extra.reason',
            'window_closed',
          ),
        ),
      );
    });
  });

  group('getEndSessionResponse — hiddenIFrame', () {
    test(
      'resolves the OidcEndSessionResponse posted on the BroadcastChannel',
      () async {
        const channelName = 'flows-hidden-endsession-ok';
        final options = OidcPlatformSpecificOptions_Web(
          navigationMode:
              OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
          broadcastChannel: channelName,
        );

        final future = core.getEndSessionResponse(
          _endSessionMetadata(),
          const OidcEndSessionRequest(clientId: 'client-1', state: 'es-state'),
          options,
          const {},
        );
        await Future<void>.delayed(Duration.zero);

        final channel = web.BroadcastChannel(channelName);
        // ignore: unnecessary_lambdas
        addTearDown(() => channel.close());
        channel.postMessage('https://app.example.com/cb?state=es-state'.toJS);

        final resp = await future.timeout(const Duration(seconds: 8));
        expect(resp, isNotNull);
        expect(resp!.state, 'es-state');
      },
    );
  });

  group('listenToFrontChannelLogoutRequests — rejection branches', () {
    test('a path-scoped listenOn rejects non-string, unparseable, '
        'path-mismatch and missing-requestType messages, then yields the '
        'matching one', () async {
      expect(Uri.tryParse(_unparseable), isNull);

      const channelName = 'flows-fc-path';
      final stream = core.listenToFrontChannelLogoutRequests(
        Uri.parse('https://app.example.com/logout'),
        const OidcFrontChannelRequestListeningOptions_Web(
          broadcastChannel: channelName,
        ),
      );
      final received = <OidcFrontChannelLogoutIncomingRequest>[];
      final sub = stream.listen(received.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());

      channel
        // non-string -> rejected
        ..postMessage(9.toJS)
        // unparseable -> rejected
        ..postMessage(_unparseable.toJS)
        // path mismatch -> rejected
        ..postMessage(
          'https://app.example.com/other?requestType=front-channel-logout'.toJS,
        )
        // path matches but no default requestType -> rejected
        ..postMessage('https://app.example.com/logout?foo=bar'.toJS)
        // the match
        ..postMessage(
          'https://app.example.com/logout'
                  '?requestType=front-channel-logout&sid=match-path'
              .toJS,
        );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(received, hasLength(1));
      expect(received.single.sid, 'match-path');
    });

    test('a query-scoped listenOn rejects a query mismatch, then yields the '
        'matching one', () async {
      const channelName = 'flows-fc-query';
      final stream = core.listenToFrontChannelLogoutRequests(
        Uri.parse('https://app.example.com/logout?sid=expected'),
        const OidcFrontChannelRequestListeningOptions_Web(
          broadcastChannel: channelName,
        ),
      );
      final received = <OidcFrontChannelLogoutIncomingRequest>[];
      final sub = stream.listen(received.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());

      channel
        // query mismatch (sid differs) -> rejected
        ..postMessage('https://app.example.com/logout?sid=WRONG'.toJS)
        // the match
        ..postMessage('https://app.example.com/logout?sid=expected'.toJS);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(received, hasLength(1));
      expect(received.single, isA<OidcFrontChannelLogoutIncomingRequest>());
    });
  });

  group('monitorSessionStatus', () {
    test('emits changed/unchanged/error/unknown results for iframe messages '
        'and honors pause/resume/cancel', () async {
      final origin = web.window.location.origin;
      // A same-origin URL that the package:test server answers (with a 404),
      // so the iframe fires `onLoad` and onListen proceeds to attach the
      // window message listener. Its origin matches the messages we post.
      final checkSession = Uri.parse('$origin/__oidc_monitor_probe__');

      final results = <OidcMonitorSessionResult>[];
      final stream = core.monitorSessionStatus(
        checkSessionIframe: checkSession,
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-1',
          sessionState: 'sess-1',
          interval: Duration(milliseconds: 200),
        ),
      );
      final sub = stream.listen(results.add);
      addTearDown(() async {
        await sub.cancel();
        web.document.getElementById('oidc-session-management-iframe')?.remove();
      });

      // Give onListen time to load the iframe and attach the window listener.
      await Future<void>.delayed(const Duration(seconds: 2));

      void post(String data) => web.window.postMessage(data.toJS, origin.toJS);

      post('changed');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      post('unchanged');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      post('error');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      post('totally-unexpected-payload');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(
        results.any((r) => r.isChanged()),
        isTrue,
        reason: 'expected a changed result',
      );
      expect(
        results.any((r) => r.isValidResult() && !r.isChanged()),
        isTrue,
        reason: 'expected an unchanged result',
      );
      expect(
        results.any((r) => r.isError()),
        isTrue,
        reason: 'expected an error result',
      );
      expect(
        results.any(
          (r) => r.getUnknownResult() == 'totally-unexpected-payload',
        ),
        isTrue,
        reason: 'expected an unknown result carrying the raw payload',
      );

      final resultsAfterAssertions = results.length;

      // A non-string message (matching origin, iframe still present) is
      // dropped at the `isA<JSString>` guard, not surfaced as a result.
      web.window.postMessage(99.toJS, origin.toJS);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Once the iframe is gone, both the incoming-message handler (its
      // getElementById is null) and the periodic sendCheckSession (its target
      // is no longer an <iframe>) bail out. The message is ignored.
      web.document.getElementById('oidc-session-management-iframe')?.remove();
      post('ignored-after-iframe-removed');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        results.length,
        resultsAfterAssertions,
        reason: 'non-string and post-removal messages must be ignored',
      );

      // onPause / onResume.
      sub.pause();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      sub.resume();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      // onCancel runs via the tearDown.
    });
  });
}
