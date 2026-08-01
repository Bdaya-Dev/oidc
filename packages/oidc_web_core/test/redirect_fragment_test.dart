@TestOn('js')
library;

// `OidcAuthorizeResponse.accessToken` / `idToken` / `tokenType` are deprecated
// because they are only populated by the implicit and hybrid flows -- which is
// exactly what this file exercises. Asserting the front-channel fields is the
// point: reading them from the token endpoint instead would test a different
// flow and prove nothing about the fragment.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Hybrid (`code id_token`) and Implicit (`id_token token`) default to
// `response_mode=fragment` (OIDC Core §3.3.2.5 / §3.2.2.5), so the whole
// authorization response arrives after the `#`. The web transport is the only
// one that can observe a fragment without native help: `redirect.html` relays
// `window.location.toString()` -- fragment included -- over the redirect
// BroadcastChannel, and `OidcWebCore` parses it.
//
// Every pre-existing test on this channel posts a QUERY response, so the
// fragment half of that contract was asserted nowhere. These tests post
// fragment responses shaped exactly like the ones the OpenID conformance
// suite's hybrid/implicit modules return.

OidcProviderMetadata _authMetadata() => OidcProviderMetadata.fromJson(const {
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

OidcAuthorizeRequest _authRequest({
  required List<String> responseType,
  String? state,
}) => OidcAuthorizeRequest(
  responseType: responseType,
  clientId: 'client-1',
  redirectUri: Uri.parse('https://app.example.com/cb'),
  scope: const ['openid'],
  state: state,
  // OIDC Core §3.2.2.1 / §3.3.2.1: `nonce` is REQUIRED whenever response_type
  // contains `id_token` or `token`, and OidcAuthorizeRequest enforces it.
  nonce: 'n-$state',
  // 'none' so the hiddenIFrame navigation mode is permitted (no user
  // interaction), letting the test post the response on the channel directly.
  prompt: const ['none'],
);

OidcPlatformSpecificOptions_Web _options(String channelName) =>
    OidcPlatformSpecificOptions_Web(
      navigationMode:
          OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
      broadcastChannel: channelName,
    );

void _postRedirect(web.BroadcastChannel channel, String uri) {
  channel.postMessage(
    jsonEncode({'v': 2, 'type': 'redirect', 'uri': uri}).toJS,
  );
}

void main() {
  const core = OidcWebCore();

  group('fragment authorization response (hybrid / implicit)', () {
    test('resolves a hybrid `code id_token` response delivered in the '
        'fragment', () async {
      const channelName = 'frag-hybrid';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['code', 'id_token'], state: 'st-hyb'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(
        channel,
        'https://app.example.com/cb'
        '#code=hyb-code&id_token=eyJ0.eyJ1.De_Wt4&state=st-hyb',
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'hyb-code');
      expect(resp.state, 'st-hyb');
      expect(resp.idToken, 'eyJ0.eyJ1.De_Wt4');
    });

    test('resolves an implicit `id_token token` response delivered in the '
        'fragment', () async {
      const channelName = 'frag-implicit';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(
          responseType: const ['id_token', 'token'],
          state: 'st-imp',
        ),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(
        channel,
        'https://app.example.com/cb'
        '#access_token=aA.bB-cC_dD&token_type=bearer'
        '&id_token=eyJ0.eyJ1.De_Wt4&state=st-imp&expires_in=3600',
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.state, 'st-imp');
      expect(resp.accessToken, 'aA.bB-cC_dD');
      expect(resp.idToken, 'eyJ0.eyJ1.De_Wt4');
      expect(resp.tokenType, 'bearer');
    });

    test('rejects a fragment response whose state does not match the '
        'request', () async {
      const channelName = 'frag-state-mismatch';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['id_token'], state: 'st-real'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(
        channel,
        'https://app.example.com/cb#id_token=forged&state=st-attacker',
      );
      // The matching response must still be accepted afterwards.
      _postRedirect(
        channel,
        'https://app.example.com/cb#id_token=genuine&state=st-real',
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.idToken, 'genuine');
    });

    // The redirect BroadcastChannel is shared by every context on the origin,
    // so a flow receives messages it did not cause: a late redirect from a
    // previous module, a stray `redirect.html` tab, a post-logout redirect that
    // carries no `state`.
    //
    // `resolveAuthorizeResponseParameters` THROWS when a Uri carries none of
    // `state`/`error`/`response` in either the query or the fragment
    // (oidc_core facade.dart:739-742). It is called from inside the channel's
    // `onmessage` callback, so that throw does not fail the flow -- it escapes
    // into the browser as an uncaught error and the response `Completer` is
    // simply never completed. The flow then burns the whole
    // `flowTimeoutSeconds`, and with the default (`null`) it waits forever.
    //
    // This is not hypothetical: the web job's stderr carries exactly that
    // exception, thrown from `BroadcastChannel.ret`
    // (`OidcException: ... key (state) ...`, run 90178636000). An unresolvable
    // message is not this flow's message; it must be ignored, not fatal.
    test('an unresolvable message on the shared channel is ignored, and the '
        'real fragment response still resolves', () async {
      const channelName = 'frag-unresolvable';
      // Asserting only that the genuine response resolves does NOT pin the
      // guard: an unguarded throw escapes the JS callback asynchronously and
      // does not stop the NEXT message being handled, so that assertion holds
      // either way (proved by reverting the try/catch). The catch itself is
      // the only observable difference, so watch for the record it emits.
      final caught = <String>[];
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen((r) {
        if (r.message.contains('carries no resolvable authorization')) {
          caught.add(r.message);
        }
      });
      addTearDown(() {
        sub.cancel();
        Logger.root.level = previousLevel;
      });

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['id_token'], state: 'st-survive'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      // No state, no error, no response -- in neither the query nor the
      // fragment. This is what a post-logout redirect or a bare
      // `redirect.html` load posts.
      _postRedirect(channel, 'https://app.example.com/cb');
      _postRedirect(channel, 'https://app.example.com/cb#foo=bar');
      // The genuine response, after the noise.
      _postRedirect(
        channel,
        'https://app.example.com/cb#id_token=survived&state=st-survive',
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.idToken, 'survived');
      // Both unresolvable messages must have reached the catch. Revert the
      // try/catch and this is 0 while every assertion above still passes.
      expect(caught, hasLength(2));
    });

    test('surfaces an OP error delivered in the fragment (RFC 6749 '
        '§4.1.2.1)', () async {
      const channelName = 'frag-error';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['id_token'], state: 'st-err'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(
        channel,
        'https://app.example.com/cb'
        '#error=access_denied&error_description=user+said+no&state=st-err',
      );

      await expectLater(
        future.timeout(const Duration(seconds: 8)),
        throwsA(isA<OidcException>()),
      );
    });
  });

  group('fragment end-session response', () {
    // `_getResponseUri` gates an end-session response with the same
    // query-OR-fragment resolver the authorize path uses, so a fragment-borne
    // response passes the `state` check and reaches
    // `getEndSessionResponse` -- which then read `respUri.queryParameters`
    // only, and produced an empty response with every field null.
    //
    // The asymmetry is the defect: one half of the same function resolves both
    // locations and the other half resolves one. OIDC RP-Initiated Logout 1.0
    // §3 defines the response on the query, so this is not a spec gap; it is a
    // parser that silently disagrees with its own guard.
    test('reads a state delivered in the fragment instead of returning an '
        'empty response', () async {
      const channelName = 'frag-endsession';
      final future = core.getEndSessionResponse(
        OidcProviderMetadata.fromJson(const {
          'issuer': 'https://op.example.com',
          'end_session_endpoint': 'https://op.example.com/logout',
        }),
        const OidcEndSessionRequest(clientId: 'client-1', state: 'es-frag'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(channel, 'https://app.example.com/cb#state=es-frag');

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.state, 'es-frag');
    });

    test('still reads a state delivered in the query', () async {
      const channelName = 'query-endsession';
      final future = core.getEndSessionResponse(
        OidcProviderMetadata.fromJson(const {
          'issuer': 'https://op.example.com',
          'end_session_endpoint': 'https://op.example.com/logout',
        }),
        const OidcEndSessionRequest(clientId: 'client-1', state: 'es-query'),
        _options(channelName),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      _postRedirect(channel, 'https://app.example.com/cb?state=es-query');

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.state, 'es-query');
    });
  });
}
