@TestOn('js')
library;

// `oidc_web_core` unconditionally depends on `package:web`
// (`dart:js_interop`), so its entire barrel only compiles for a web
// (js/wasm) compile target — it can never run on the `vm` platform. This
// test therefore runs only on `js` (chrome/firefox), matching the rest of
// this package's suite (see oidc_web_core_test.dart). Coverage for this
// package must be collected with `dart test -p chrome --coverage=...`
// rather than the vm-default invocation, since `dart test --coverage`
// (implicit vm platform) never even attempts to compile this suite.
import 'dart:js_interop';

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// Builds a minimal, valid [OidcUserManagerWeb] for exercising its
/// `OidcPlatform` delegate overrides directly (without running a full
/// login/logout flow through `OidcUserManagerBase`).
OidcUserManagerWeb _buildManager({bool withEndSessionEndpoint = false}) {
  return OidcUserManagerWeb(
    discoveryDocument: OidcProviderMetadata.fromJson({
      'issuer': 'https://op.example.com',
      'authorization_endpoint': 'https://op.example.com/authorize',
      'token_endpoint': 'https://op.example.com/token',
      if (withEndSessionEndpoint)
        'end_session_endpoint': 'https://op.example.com/endsession',
    }),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('https://app.example.com/cb'),
    ),
  );
}

void main() {
  group('oidc_web_core library surface', () {
    test('OidcWebCore is a real, const, stateless entry point', () {
      const a = OidcWebCore();
      const b = OidcWebCore();
      // `const` construction canonicalizes identical const instances.
      expect(identical(a, b), isTrue);
    });

    test('OidcUserManagerWeb.isWeb is true, per its documented override', () {
      final manager = _buildManager();
      expect(manager.isWeb, isTrue);
    });

    test('OidcUserManagerWeb.prepareForRedirectFlow is a no-op in samePage '
        'navigation mode (no window.open, no preparation payload)', () {
      final manager = _buildManager();
      // In `samePage` navigation mode, `_prepareWindow` returns null (no
      // popup / new tab is opened), so the preparation payload must be
      // empty.
      final result = manager.prepareForRedirectFlow(
        const OidcPlatformSpecificOptions(
          web: OidcPlatformSpecificOptions_Web(
            navigationMode:
                OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
          ),
        ),
      );
      expect(result, isEmpty);
    });

    test('OidcUserManagerWeb.getAuthorizationResponse delegates to '
        'OidcWebCore: a metadata document without an authorization_endpoint '
        'surfaces as an OidcException synchronously (no popup/navigation '
        'ever happens)', () async {
      final manager = _buildManager();
      final metadata = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
        'token_endpoint': 'https://op.example.com/token',
      });
      final request = OidcAuthorizeRequest(
        responseType: const ['code'],
        clientId: 'client-1',
        redirectUri: Uri.parse('https://app.example.com/cb'),
        scope: const ['openid'],
      );

      await expectLater(
        manager.getAuthorizationResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('OidcUserManagerWeb.getEndSessionResponse delegates to OidcWebCore: '
        'a metadata document without an end_session_endpoint surfaces as an '
        'OidcException synchronously', () async {
      final manager = _buildManager();
      final metadata = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
        'authorization_endpoint': 'https://op.example.com/authorize',
        'token_endpoint': 'https://op.example.com/token',
      });
      const request = OidcEndSessionRequest(clientId: 'client-1');

      await expectLater(
        manager.getEndSessionResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        ),
        throwsA(isA<OidcException>()),
      );
    });

    test('OidcUserManagerWeb.getEndSessionResponse delegates to OidcWebCore: '
        'given an end_session_endpoint, samePage navigation returns null '
        '(the response only ever arrives via the redirected page)', () async {
      final manager = _buildManager(withEndSessionEndpoint: true);
      // `samePage` mode performs a REAL `window.location.assign()` before
      // returning null. With a cross-origin endpoint the navigation commits
      // an error page a beat later and destroys this suite's browser context
      // mid-run — a silent hang with no failure and no timeout, because the
      // in-browser timers die with the context (CI run 29209713144 froze on
      // both matrix legs this way). So: point the endpoint at THIS page, and
      // pre-align the document URL via history.replaceState (which does not
      // navigate) to the exact URL the library will assign — the assign then
      // differs only in fragment and stays a same-document navigation.
      const request = OidcEndSessionRequest(clientId: 'client-1');
      final endpoint = Uri.parse(
        web.window.location.href,
      ).replace(fragment: 'end-session');
      final target = request.generateUri(endpoint);
      final originalHref = web.window.location.href;
      web.window.history.replaceState(
        null,
        '',
        target.replace(fragment: 'pre-aligned').toString(),
      );
      addTearDown(
        () => web.window.history.replaceState(null, '', originalHref),
      );
      final metadata = OidcProviderMetadata.fromJson({
        'issuer': 'https://op.example.com',
        'authorization_endpoint': 'https://op.example.com/authorize',
        'token_endpoint': 'https://op.example.com/token',
        'end_session_endpoint': endpoint.toString(),
      });

      final result = await manager.getEndSessionResponse(
        metadata,
        request,
        const OidcPlatformSpecificOptions(
          web: OidcPlatformSpecificOptions_Web(
            navigationMode:
                OidcPlatformSpecificOptions_Web_NavigationMode.samePage,
          ),
        ),
        const {},
      );
      expect(result, isNull);
    });

    test('OidcUserManagerWeb.listenToFrontChannelLogoutRequests delegates to '
        'OidcWebCore and yields a request parsed out of a same-origin '
        'BroadcastChannel message', () async {
      final manager = _buildManager();
      final stream = manager.listenToFrontChannelLogoutRequests(
        // no path segments and no query -- matched via the default
        // `requestType=front-channel-logout` check.
        Uri.parse('https://app.example.com'),
        const OidcFrontChannelRequestListeningOptions(),
      );
      expect(stream.isBroadcast, isFalse);

      final received = stream.first;
      // Let the stream's `onListen` attach its BroadcastChannel handler
      // before we post to it.
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(
        OidcFrontChannelRequestListeningOptions_Web.defaultBroadcastChannel,
      );
      // `close` is an external extension-type interop member -- dart2js
      // disallows tearing it off, so this can't be
      // `addTearDown(channel.close)`.
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      channel.postMessage(
        'https://app.example.com/?requestType=front-channel-logout'
                '&sid=session-42'
            .toJS,
      );

      final result = await received.timeout(const Duration(seconds: 5));
      expect(result.sid, 'session-42');
    });

    test('OidcUserManagerWeb.monitorSessionStatus delegates to OidcWebCore, '
        'which creates a hidden iframe every time you listen to it -- i.e. '
        'the returned stream must be single-subscription, not broadcast', () {
      final manager = _buildManager();
      final stream = manager.monitorSessionStatus(
        checkSessionIframe: Uri.parse('https://op.example.com/checksession'),
        request: const OidcMonitorSessionStatusRequest(
          clientId: 'client-1',
          sessionState: 'state-1',
          interval: Duration(seconds: 30),
        ),
      );
      expect(stream.isBroadcast, isFalse);
    });
  });
}
