@TestOn('js')
library;

// ignore_for_file: prefer_const_constructors

import 'dart:async';
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

    test('flowTimeoutSeconds bounds a login nobody ever completes '
        '(skips when window.open is blocked)', () async {
      // The window-closed detector above is the ONLY other way out of this
      // await, and it disarms itself when COOP severs the WindowProxy. So a
      // user who opens the login and walks away leaves a future pending for
      // the lifetime of the tab. hiddenIframeTimeout does not apply here --
      // it bounds the iframe mode only.
      //
      // Note what failure looks like without the fix: this test does not
      // fail, it HANGS, until the runner gives up. That is precisely the
      // behaviour being removed, and it is why the option exists.
      const channelName = 'flows-flow-timeout';
      final options = OidcPlatformSpecificOptions_Web(
        broadcastChannel: channelName,
        flowTimeoutSeconds: 1,
      );
      final preparation = core.prepareForRedirectFlow(options);
      final win = preparation['web_window'] as web.Window?;
      if (win == null) {
        markTestSkipped('window.open returned null (no user gesture).');
        return;
      }

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'timeout-state'),
        options,
        preparation,
      );

      // Nothing is ever posted on the channel and the window is left open,
      // so the timeout is the only thing that can resolve this.
      // Wrapped, not raw. The sibling window_closed path throws OidcException,
      // and every documented failure contract in this library promises
      // OidcException -- a bare TimeoutException slips past an app that
      // catches exactly what the docs tell it to catch.
      await expectLater(
        future,
        throwsA(
          isA<OidcException>().having(
            (e) => e.extra['reason'],
            'extra.reason',
            'flow_timeout',
          ),
        ),
      );
      // The flow must also clean up after itself on the timeout path, not
      // just the success path.
      expect(
        win.closed,
        isTrue,
        reason: 'a timed-out flow must close the window it opened',
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
      // A real page (not a 404) so it can run script: it echoes back
      // whatever is posted to it, so a reply's `event.source` is genuinely
      // this monitor's iframe window, as `onMessageReceived` now requires
      // (#474) -- a bare same-origin `window.postMessage` from the test
      // itself no longer matches.
      final checkSession = Uri.base.resolve(
        'fixtures/session_iframe_echo.html',
      );

      final results = <OidcMonitorSessionResult>[];
      final stream = core.monitorSessionStatus(
        checkSessionIframe: checkSession,
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-1',
          sessionState: 'sess-1',
          // Large enough that the periodic keep-alive ping (which the live
          // fixture also echoes back, unlike the old dead 404 probe) only
          // fires once, immediately, during setup -- not again during this
          // test's exact-count assertions below.
          interval: Duration(seconds: 30),
        ),
      );
      final sub = stream.listen(results.add);
      addTearDown(() async {
        await sub.cancel();
        _removeAllSessionMonitorIframes();
      });

      // Give onListen time to load the iframe and attach the window listener.
      await Future<void>.delayed(const Duration(seconds: 2));

      final iframes = _sessionMonitorIframes();
      expect(
        iframes,
        hasLength(1),
        reason: "the monitor's iframe should be attached by now",
      );
      final iframeWindow =
          (iframes.single as web.HTMLIFrameElement).contentWindow!;

      // Posts into the monitor's OWN iframe, which echoes back to
      // `window.parent` -- mirroring the real OP protocol, and the only way
      // to produce a reply whose `event.source` matches (#474).
      void post(String data) =>
          iframeWindow.postMessage('reply:$data'.toJS, origin.toJS);

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

      // A non-string message (matching origin AND source, iframe still
      // present) is dropped at the `isA<JSString>` guard, not surfaced as a
      // result. The fixture echoes back the NUMBER 99 (not a string) for
      // this specific command.
      iframeWindow.postMessage('send-nonstring'.toJS, origin.toJS);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Once the iframe is gone, both the incoming-message handler (its
      // own iframe is no longer connected) and the periodic sendCheckSession
      // (same check) bail out. The message is ignored, however it arrives --
      // a bare same-origin self-post is enough here since connectivity alone
      // is what must reject it.
      _removeAllSessionMonitorIframes();
      web.window.postMessage('ignored-after-iframe-removed'.toJS, origin.toJS);
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

    test("cancelling an older monitor does not remove a newer monitor's "
        'iframe, which keeps receiving replies (#474)', () async {
      final origin = web.window.location.origin;
      final checkSession = Uri.base.resolve(
        'fixtures/session_iframe_echo.html',
      );

      final resultsA = <OidcMonitorSessionResult>[];
      final streamA = core.monitorSessionStatus(
        checkSessionIframe: checkSession,
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-a',
          sessionState: 'sess-a',
          interval: Duration(milliseconds: 100),
        ),
      );
      final subA = streamA.listen(resultsA.add);
      addTearDown(() async {
        await subA.cancel();
        _removeAllSessionMonitorIframes();
      });

      // Let A's iframe load and attach before starting B, matching the
      // "an older monitor is still running when a newer one starts"
      // scenario from #474.
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        _sessionMonitorIframes(),
        hasLength(1),
        reason: "monitor A's iframe should be in the DOM",
      );

      final resultsB = <OidcMonitorSessionResult>[];
      final streamB = core.monitorSessionStatus(
        checkSessionIframe: checkSession,
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-b',
          sessionState: 'sess-b',
          interval: Duration(milliseconds: 100),
        ),
      );
      final subB = streamB.listen(resultsB.add);
      addTearDown(() async {
        await subB.cancel();
        _removeAllSessionMonitorIframes();
      });

      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        _sessionMonitorIframes(),
        hasLength(2),
        reason:
            "starting B must not remove A's iframe, and both should "
            'now be present',
      );

      // Cancel the OLDER monitor (A).
      await subA.cancel();

      final remaining = _sessionMonitorIframes();
      expect(
        remaining,
        hasLength(1),
        reason:
            "cancelling A must remove only A's own iframe, leaving "
            "B's iframe in the DOM",
      );

      // Drive a reply through B's own iframe -- the only one left, and the
      // only source `event.source` will now accept (#474).
      final iframeBWindow =
          (remaining.single as web.HTMLIFrameElement).contentWindow!;

      resultsB.clear();
      iframeBWindow.postMessage('reply:changed'.toJS, origin.toJS);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        resultsB,
        isNotEmpty,
        reason:
            'cancelling the older monitor (A) must not stop the '
            'newer monitor (B) from receiving session-status messages',
      );
    });

    test('cancelling before `load` fires stops setup (no listener/timer '
        'attached) and removes the iframe (#474)', () async {
      final origin = web.window.location.origin;
      final checkSession = Uri.parse(
        '$origin/__oidc_monitor_probe_474_cancel_before_load__',
      );

      final before = _sessionMonitorIframes().length;

      final results = <OidcMonitorSessionResult>[];
      final stream = core.monitorSessionStatus(
        checkSessionIframe: checkSession,
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-cancel-before-load',
          sessionState: 'sess-cancel-before-load',
          interval: Duration(milliseconds: 50),
        ),
      );
      final sub = stream.listen(results.add);
      // Cancel synchronously (no `await` since `.listen()`), i.e. well
      // before the browser could ever fire the iframe's `load` event.
      await sub.cancel();

      // Give plenty of time for `load` to have fired had the monitor
      // still owned the iframe, and for a (never-started) periodic timer
      // to have posted to it.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        _sessionMonitorIframes().length,
        before,
        reason:
            'a monitor cancelled before `load` must not leave its '
            'iframe in the DOM',
      );

      void post(String data) => web.window.postMessage(data.toJS, origin.toJS);
      post('changed');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        results,
        isEmpty,
        reason:
            'a monitor cancelled before `load` must never attach its '
            'message listener or periodic timer',
      );
    });

    test(
      "a reply from one monitor's iframe is never delivered to a "
      'different monitor on the same origin (event.source check, #474)',
      () async {
        // Both monitors point at the SAME check_session_iframe URL -- the
        // "two concurrent monitors against the same OP origin" scenario the
        // reviewer flagged: origin-only filtering can't tell their replies
        // apart, only `event.source` (this monitor's own iframe window) can.
        //
        // `Uri.base.resolve` (rather than building `$origin/...` directly)
        // mirrors how the browser itself would resolve a relative `src`, so
        // this doesn't depend on package:test's server root matching the
        // package root.
        final fixture = Uri.base.resolve('fixtures/session_iframe_echo.html');
        expect(
          fixture.origin,
          web.window.location.origin,
          reason:
              'sanity check: the fixture must resolve same-origin, or the '
              "monitors' eventOrigin check would reject it outright and "
              'this test would prove nothing',
        );

        final resultsA = <OidcMonitorSessionResult>[];
        final streamA = core.monitorSessionStatus(
          checkSessionIframe: fixture,
          request: const OidcMonitorSessionStatusRequest(
            clientId: 'client-a',
            sessionState: 'sess-a',
            interval: Duration(milliseconds: 150),
          ),
        );
        final subA = streamA.listen(resultsA.add);
        addTearDown(() async {
          await subA.cancel();
          _removeAllSessionMonitorIframes();
        });

        final resultsB = <OidcMonitorSessionResult>[];
        final streamB = core.monitorSessionStatus(
          checkSessionIframe: fixture,
          request: const OidcMonitorSessionStatusRequest(
            clientId: 'client-b',
            sessionState: 'sess-b',
            interval: Duration(milliseconds: 150),
          ),
        );
        final subB = streamB.listen(resultsB.add);
        addTearDown(() async {
          await subB.cancel();
          _removeAllSessionMonitorIframes();
        });

        // Let both iframes load and exchange a few request/reply round
        // trips on their periodic interval.
        await Future<void>.delayed(const Duration(seconds: 2));

        bool received(List<OidcMonitorSessionResult> results, String state) =>
            results.any((r) => r.getUnknownResult() == 'changed:$state');

        expect(
          received(resultsA, 'sess-a'),
          isTrue,
          reason: "monitor A should receive its own iframe's reply",
        );
        expect(
          received(resultsB, 'sess-b'),
          isTrue,
          reason: "monitor B should receive its own iframe's reply",
        );
        expect(
          received(resultsA, 'sess-b'),
          isFalse,
          reason: "monitor A must not receive monitor B's iframe reply",
        );
        expect(
          received(resultsB, 'sess-a'),
          isFalse,
          reason: "monitor B must not receive monitor A's iframe reply",
        );
      },
    );
  });
}

/// All hidden `check_session_iframe`s currently owned by some
/// `monitorSessionStatus` monitor. Each monitor gets a uniquely-suffixed id
/// (`oidc-session-management-iframe-<n>`, #474), so DOM presence is checked
/// by id prefix rather than `getElementById` with the old fixed id.
List<web.Element> _sessionMonitorIframes() {
  final nodeList = web.document.querySelectorAll(
    'iframe[id^="oidc-session-management-iframe"]',
  );
  return [
    for (var i = 0; i < nodeList.length; i++) nodeList.item(i)! as web.Element,
  ];
}

void _removeAllSessionMonitorIframes() {
  for (final iframe in _sessionMonitorIframes()) {
    iframe.remove();
  }
}
