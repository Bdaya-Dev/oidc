@TestOn('js')
library;

// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:js_interop';

import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Exercises the structured redirect wire v2 protocol between the app-side
// consumer in `lib/src/oidc_web_core.dart` and the bundled `redirect.html`
// template:
//
//  * the page posts `{"v":2,"type":"redirect","uri":...}` (v2) OR a bare
//    redirect URL string (legacy) on the redirect BroadcastChannel, and
//  * after processing, the app posts
//    `{"v":2,"type":"ack","status":"ok"|"error","message":<string?>}` back.
//
// These run in a real browser (`dart test -p chrome`) because they use the
// browser's BroadcastChannel via `package:web`.

OidcProviderMetadata _authMetadata() => OidcProviderMetadata.fromJson(const {
  'issuer': 'https://op.example.com',
  'authorization_endpoint': 'https://op.example.com/authorize',
  'token_endpoint': 'https://op.example.com/token',
});

OidcAuthorizeRequest _authRequest({String? state}) => OidcAuthorizeRequest(
  responseType: const ['code'],
  clientId: 'client-1',
  redirectUri: Uri.parse('https://app.example.com/cb'),
  scope: const ['openid'],
  state: state,
  // 'none' so the hiddenIFrame navigation mode is permitted (no user
  // interaction), letting the test post the response on the channel directly.
  prompt: const ['none'],
);

/// A hidden-iframe options bag on [channelName]; hiddenIFrame lets the flow be
/// driven purely over the BroadcastChannel with no prepared window.
OidcPlatformSpecificOptions_Web _options(String channelName) =>
    OidcPlatformSpecificOptions_Web(
      navigationMode:
          OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame,
      broadcastChannel: channelName,
    );

/// Opens a channel that records every message posted on [channelName] as a
/// decoded JSON map (non-JSON / non-map messages are dropped). Used to observe
/// the app-side `ack`.
({List<Map<String, Object?>> messages, web.BroadcastChannel channel}) _sink(
  String channelName,
) {
  final messages = <Map<String, Object?>>[];
  final channel = web.BroadcastChannel(channelName)
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
      if (decoded is Map<String, dynamic>) {
        messages.add(decoded);
      }
    }).toJS;
  return (messages: messages, channel: channel);
}

List<Map<String, Object?>> _acks(List<Map<String, Object?>> messages) =>
    messages.where((m) => m['type'] == 'ack').toList();

void main() {
  const core = OidcWebCore();

  group('redirect wire v2 — consumer accepts both formats', () {
    test('accepts the structured v2 redirect envelope', () async {
      const channelName = 'wire-accept-v2';
      final options = _options(channelName);

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-v2'),
        options,
        const {},
      );
      // Let `_getResponseUri` attach `channel.onmessage` before we post.
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      channel.postMessage(
        jsonEncode({
          'v': 2,
          'type': 'redirect',
          'uri': 'https://app.example.com/cb?state=st-v2&code=code-v2',
        }).toJS,
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'code-v2');
      expect(resp.state, 'st-v2');
    });

    test('accepts a legacy bare redirect URL string', () async {
      const channelName = 'wire-accept-legacy';
      final options = _options(channelName);

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-legacy'),
        options,
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      channel.postMessage(
        'https://app.example.com/cb?state=st-legacy&code=code-legacy'.toJS,
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'code-legacy');
      expect(resp.state, 'st-legacy');
    });

    test('ignores a v2 envelope whose type is not "redirect" (e.g. an ack '
        'echoed on the channel), then resolves on the real redirect', () async {
      const channelName = 'wire-ignore-nonredirect';
      final options = _options(channelName);

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-ignore'),
        options,
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      final channel = web.BroadcastChannel(channelName);
      // ignore: unnecessary_lambdas
      addTearDown(() => channel.close());
      channel
        // An ack envelope must not be mistaken for a redirect.
        ..postMessage(jsonEncode({'v': 2, 'type': 'ack', 'status': 'ok'}).toJS)
        // A v2 redirect envelope missing its `uri` must be ignored.
        ..postMessage(jsonEncode({'v': 2, 'type': 'redirect'}).toJS)
        // The real redirect.
        ..postMessage(
          jsonEncode({
            'v': 2,
            'type': 'redirect',
            'uri': 'https://app.example.com/cb?state=st-ignore&code=real',
          }).toJS,
        );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'real');
    });
  });

  group('redirect wire v2 — app posts an ack', () {
    test('posts an ok ack after a successful authorize response', () async {
      const channelName = 'wire-ack-ok';
      final options = _options(channelName);

      final sink = _sink(channelName);
      // `close` is an external interop member and can't be torn off.
      // ignore: unnecessary_lambdas
      addTearDown(() => sink.channel.close());

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-ok'),
        options,
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      sink.channel.postMessage(
        jsonEncode({
          'v': 2,
          'type': 'redirect',
          'uri': 'https://app.example.com/cb?state=st-ok&code=ok-code',
        }).toJS,
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.code, 'ok-code');

      // Give the ack MessageEvent a turn to be delivered to the sink.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final acks = _acks(sink.messages);
      expect(acks, isNotEmpty, reason: 'expected an ack to be posted');
      expect(acks.last['v'], 2);
      expect(acks.last['status'], 'ok');
    });

    test('posts an error ack (and rethrows) when the response is an OP error '
        'redirect per RFC 6749 §4.1.2.1', () async {
      const channelName = 'wire-ack-error';
      final options = _options(channelName);

      final sink = _sink(channelName);
      // `close` is an external interop member and can't be torn off.
      // ignore: unnecessary_lambdas
      addTearDown(() => sink.channel.close());

      final future = core.getAuthorizationResponse(
        _authMetadata(),
        _authRequest(state: 'st-err'),
        options,
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      sink.channel.postMessage(
        jsonEncode({
          'v': 2,
          'type': 'redirect',
          'uri':
              'https://app.example.com/cb?state=st-err'
              '&error=access_denied&error_description=user+said+no',
        }).toJS,
      );

      await expectLater(
        future.timeout(const Duration(seconds: 8)),
        throwsA(isA<OidcException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final acks = _acks(sink.messages);
      expect(acks, isNotEmpty, reason: 'expected an ack to be posted');
      expect(acks.last['status'], 'error');
      expect(acks.last['message'], isA<String>());
    });

    test('posts an ok ack after a processed end-session response', () async {
      const channelName = 'wire-ack-endsession';
      final options = _options(channelName);

      final sink = _sink(channelName);
      // `close` is an external interop member and can't be torn off.
      // ignore: unnecessary_lambdas
      addTearDown(() => sink.channel.close());

      final future = core.getEndSessionResponse(
        OidcProviderMetadata.fromJson(const {
          'issuer': 'https://op.example.com',
          'end_session_endpoint': 'https://op.example.com/logout',
        }),
        const OidcEndSessionRequest(clientId: 'client-1', state: 'es-state'),
        options,
        const {},
      );
      await Future<void>.delayed(Duration.zero);

      sink.channel.postMessage(
        jsonEncode({
          'v': 2,
          'type': 'redirect',
          'uri': 'https://app.example.com/cb?state=es-state',
        }).toJS,
      );

      final resp = await future.timeout(const Duration(seconds: 8));
      expect(resp, isNotNull);
      expect(resp!.state, 'es-state');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final acks = _acks(sink.messages);
      expect(acks, isNotEmpty, reason: 'expected an ack to be posted');
      expect(acks.last['status'], 'ok');
    });
  });
}
