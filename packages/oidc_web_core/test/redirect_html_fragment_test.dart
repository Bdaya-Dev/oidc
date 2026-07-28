@TestOn('js')
library;

// `OidcAuthorizeResponse.accessToken` / `idToken` are deprecated because only
// the implicit and hybrid flows populate them -- the two profiles this file
// exists to cover. Asserting them is what proves the fragment survived the
// page.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Loads the REAL `example/web/redirect.html` in a same-origin iframe and drives
// it with an actual fragment response.
//
// Web is the only http(s) transport in this library that can observe a
// fragment: a fragment is never sent to a server, so a bare loopback listener
// cannot see one, and the whole reason web CAN is that `redirect.html` runs in
// the browser and relays `window.location.toString()` -- fragment included --
// over the redirect BroadcastChannel.
//
// The example harness asserts exactly that claim, in prose, to decide whether
// to run the Hybrid and Implicit conformance profiles:
//
//     bool canReceiveFragmentResponse(String platform) =>
//         !(platform == 'linux' || platform == 'windows');
//     ///   * web (`http://localhost:.../redirect.html`) -- the page reads
//     ///     `location.hash` in JS and relays it over the BroadcastChannel. OK.
//
// Nothing executed that claim. Every other test on this channel posts a
// synthetic message with a QUERY response, which exercises the consumer and
// skips the page entirely -- so the page could stop relaying the fragment and
// no test anywhere would notice; the only signal would be two conformance
// profiles silently timing out in CI. This file closes that gap by running the
// page itself.

/// The redirect page is served from the package's own example, so the test
/// drives the shipped template rather than a copy written for the test.
/// `packages/oidc/example/web/redirect.html` (the copy the web CI job serves)
/// is asserted byte-identical to it by
/// `packages/oidc/example/test/redirect_html_parity_test.dart`.
const _redirectPage = '../example/web/redirect.html';

/// `redirect.html` hardcodes this name, and it is the package default
/// ([OidcPlatformSpecificOptions_Web.defaultBroadcastChannel]). The page cannot
/// be pointed at a per-test channel, so tests here share one and tell their
/// messages apart by `state`.
const _channel = OidcPlatformSpecificOptions_Web.defaultBroadcastChannel;

OidcProviderMetadata _authMetadata() => OidcProviderMetadata.fromJson(const {
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

OidcAuthorizeRequest _authRequest({
  required List<String> responseType,
  required String state,
}) => OidcAuthorizeRequest(
  responseType: responseType,
  clientId: 'client-1',
  redirectUri: Uri.parse('https://app.example.com/cb'),
  scope: const ['openid'],
  state: state,
  nonce: 'n-$state',
  // 'none' so hiddenIFrame is a permitted navigation mode; the flow is driven
  // by the page's own post, not by this option.
  prompt: const ['none'],
);

/// Loads `redirect.html` at [fragmentOrQuery] in a hidden iframe.
void _loadRedirectPage(String fragmentOrQuery) {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..width = '0'
    ..height = '0'
    ..style.visibility = 'hidden'
    ..style.position = 'fixed'
    ..style.left = '-1000px'
    ..src = '$_redirectPage$fragmentOrQuery';
  web.document.body!.append(iframe);
  // `remove` is an external interop member and can't be torn off.
  // ignore: unnecessary_lambdas
  addTearDown(() => iframe.remove());
}

/// Captures the `redirect` envelopes the page posts, so the relayed URL can be
/// asserted directly rather than only through its effect on the consumer.
({List<Map<String, Object?>> messages, web.BroadcastChannel channel})
_redirectSink() {
  final messages = <Map<String, Object?>>[];
  final channel = web.BroadcastChannel(_channel)
    ..onmessage = ((web.MessageEvent event) {
      final data = event.data;
      if (!data.isA<JSString>()) {
        return;
      }
      Object? decoded;
      try {
        decoded = jsonDecode((data! as JSString).toDart);
      } on FormatException {
        return;
      }
      if (decoded is Map<String, dynamic> && decoded['type'] == 'redirect') {
        messages.add(decoded);
      }
    }).toJS;
  // `close` is an external interop member and can't be torn off.
  // ignore: unnecessary_lambdas
  addTearDown(() => channel.close());
  return (messages: messages, channel: channel);
}

Future<Map<String, Object?>> _awaitRedirectCarrying(
  List<Map<String, Object?>> messages,
  String state,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    final match = messages.where((m) {
      final uri = m['uri'];
      return uri is String && uri.contains(state);
    });
    if (match.isNotEmpty) {
      return match.first;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError(
    'redirect.html posted no redirect envelope carrying "$state" within 8s. '
    'Captured: $messages',
  );
}

void main() {
  const core = OidcWebCore();

  group('redirect.html relays what it was loaded with', () {
    test('keeps the FRAGMENT intact in the URL it posts', () async {
      final sink = _redirectSink();
      const state = 'page-frag-state';
      _loadRedirectPage(
        '#access_token=aA.bB-cC_dD&token_type=bearer'
        '&id_token=eyJ0.eyJ1.De_Wt4&state=$state&expires_in=3600',
      );

      final message = await _awaitRedirectCarrying(sink.messages, state);
      expect(message['v'], 2);
      final relayed = Uri.parse(message['uri']! as String);

      // The whole point: a fragment survives the relay. If the page ever
      // switched to posting `location.search` or a stripped URL, this is the
      // assertion that fails -- instead of two conformance profiles silently
      // timing out in CI.
      expect(relayed.fragment, isNotEmpty);
      final params = Uri(query: relayed.fragment).queryParameters;
      expect(params['state'], state);
      expect(params['access_token'], 'aA.bB-cC_dD');
      expect(params['id_token'], 'eyJ0.eyJ1.De_Wt4');
      expect(params['token_type'], 'bearer');

      // And the library's own resolver reads it back as a fragment response.
      final resolved = OidcEndpoints.resolveAuthorizeResponseParameters(
        responseUri: relayed,
        resolveResponseModeByKey: OidcConstants_AuthParameters.state,
      );
      expect(
        resolved.responseMode,
        OidcConstants_AuthorizeRequest_ResponseMode.fragment,
      );
      expect(resolved.parameters[OidcConstants_AuthParameters.state], state);
    });

    test('keeps the QUERY intact in the URL it posts', () async {
      final sink = _redirectSink();
      const state = 'page-query-state';
      _loadRedirectPage('?code=basic-code&state=$state');

      final message = await _awaitRedirectCarrying(sink.messages, state);
      final relayed = Uri.parse(message['uri']! as String);
      expect(relayed.queryParameters['state'], state);
      expect(relayed.queryParameters['code'], 'basic-code');
    });
  });

  group('end to end: the real page drives the real consumer', () {
    test('a hybrid `code id_token` fragment response delivered by '
        'redirect.html completes the flow', () async {
      const state = 'page-e2e-hybrid';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['code', 'id_token'], state: state),
        // Default channel: `redirect.html` posts on the hardcoded name.
        const OidcPlatformSpecificOptions_Web(
          navigationMode:
              OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
        ),
        const {},
      );
      // Let `_getResponseUri` attach `channel.onmessage` before the page loads.
      await Future<void>.delayed(Duration.zero);

      _loadRedirectPage(
        '#code=page-code&id_token=eyJ0.eyJ1.De_Wt4&state=$state',
      );

      final resp = await future.timeout(const Duration(seconds: 10));
      expect(resp, isNotNull);
      expect(resp!.code, 'page-code');
      expect(resp.state, state);
      expect(resp.idToken, 'eyJ0.eyJ1.De_Wt4');
    });

    test('an implicit `id_token token` fragment response delivered by '
        'redirect.html completes the flow', () async {
      const state = 'page-e2e-implicit';
      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(responseType: const ['id_token', 'token'], state: state),
        const OidcPlatformSpecificOptions_Web(
          navigationMode:
              OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
        ),
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      _loadRedirectPage(
        '#access_token=aA.bB-cC_dD&token_type=bearer'
        '&id_token=eyJ0.eyJ1.De_Wt4&state=$state&expires_in=3600',
      );

      final resp = await future.timeout(const Duration(seconds: 10));
      expect(resp, isNotNull);
      expect(resp!.state, state);
      expect(resp.accessToken, 'aA.bB-cC_dD');
      expect(resp.idToken, 'eyJ0.eyJ1.De_Wt4');
    });
  });
}
