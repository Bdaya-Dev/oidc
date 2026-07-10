import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_darwin/oidc_darwin.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

/// Injectable [OidcAppleHostApi] stand-in that throws a raw
/// [MissingPluginException] directly (bypassing the Pigeon channel), used to
/// exercise `_guard`'s "no native plugin registered at all" branch. Pigeon's
/// generated `send()` always resolves under `TestDefaultBinaryMessengerBinding`
/// (an unregistered channel decodes to a `channel-error` `PlatformException`,
/// covered separately), so a real `MissingPluginException` can only be
/// produced this way in a unit test.
class _MissingPluginHostApi extends OidcAppleHostApi {
  @override
  Future<String?> authorizeApple(
    String url,
    String? redirectUri,
    String? callbackScheme,
    bool preferEphemeral,
    Map<String, Object?> options,
  ) {
    throw MissingPluginException('no implementation found');
  }
}

OidcAuthorizeRequest _authRequest() => OidcAuthorizeRequest(
  clientId: 'client-1',
  redirectUri: Uri.parse('com.example.app://callback'),
  responseType: const [OidcConstants_AuthorizationEndpoint_ResponseType.code],
  scope: const ['openid'],
  state: 'state-1',
);

/// Base Pigeon channel name for [OidcAppleHostApi] (must match the native Swift
/// `OidcAppleHostApiSetup.setUp` registration). Keyed on the platform_interface
/// package, NOT on oidc_ios/oidc_macos/oidc_darwin, so it is unchanged by the
/// package merge.
const _hostApiPrefix =
    'dev.flutter.pigeon.oidc_platform_interface.OidcAppleHostApi';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = OidcAppleHostApi.pigeonChannelCodec;

  /// Mocks a native [OidcAppleHostApi] method at the Pigeon channel level.
  void mockHostApi(
    String method,
    Future<Object?> Function(List<Object?> args) handler,
  ) {
    final name = '$_hostApiPrefix.$method';
    messenger.setMockMessageHandler(name, (ByteData? message) async {
      final args =
          (codec.decodeMessage(message) as List<Object?>?) ?? <Object?>[];
      try {
        final result = await handler(args);
        return codec.encodeMessage(<Object?>[result]);
      } on PlatformException catch (e) {
        return codec.encodeMessage(<Object?>[e.code, e.message, e.details]);
      }
    });
  }

  final metadata = OidcProviderMetadata.fromJson(const {
    'issuer': 'https://op.example.com',
    'authorization_endpoint': 'https://op.example.com/authorize',
    'token_endpoint': 'https://op.example.com/token',
    'end_session_endpoint': 'https://op.example.com/logout',
  });

  tearDown(() {
    for (final method in ['authorizeApple', 'endSessionApple', 'cancelApple']) {
      messenger.setMockMessageHandler('$_hostApiPrefix.$method', null);
    }
  });

  test('can be registered', () {
    OidcDarwin.registerWith();
    expect(OidcPlatform.instance, isA<OidcDarwin>());
  });

  test(
    'forwards apple options (callbackMode + additionalHeaderFields)',
    () async {
      List<Object?>? received;
      mockHostApi('authorizeApple', (args) async {
        received = args;
        return 'com.example.app://callback?code=c&state=state-1';
      });

      await OidcDarwin().getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(
          ios: OidcNativeOptionsApple(
            callbackMode: OidcAppleCallbackMode.https,
            additionalHeaderFields: {'X-Test': 'yes'},
          ),
        ),
        const {},
      );

      // Pigeon authorizeApple args:
      // [url, redirectUri, callbackScheme, preferEphemeral, options].
      final opts = received![4]! as Map<Object?, Object?>;
      expect(opts['callbackMode'], 'https');
      final headers = opts['additionalHeaderFields']! as Map<Object?, Object?>;
      expect(headers['X-Test'], 'yes');
    },
  );

  test('forwards apple flowTimeoutSeconds in the native options map', () async {
    List<Object?>? received;
    mockHostApi('authorizeApple', (args) async {
      received = args;
      return 'com.example.app://callback?code=c&state=state-1';
    });

    await OidcDarwin().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(
        ios: OidcNativeOptionsApple(flowTimeoutSeconds: 30),
      ),
      const {},
    );

    // Native OidcPlugin.scheduleFlowTimeout reads opts['flowTimeoutSeconds']
    // to arm the timeout; assert the Dart->native wiring forwards the value
    // (the Swift timer itself is exercised by the iOS integration job).
    final opts = received![4]! as Map<Object?, Object?>;
    expect(opts['flowTimeoutSeconds'], 30);
  });

  test(
    'wraps a missing native plugin (channel-error) as OidcException',
    () async {
      await expectLater(
        OidcDarwin().getAuthorizationResponse(
          metadata,
          _authRequest(),
          const OidcPlatformSpecificOptions(),
          const {},
        ),
        throwsA(isA<OidcException>()),
      );
    },
  );

  test('getAuthorizationResponse builds the URL in Dart and parses the native '
      'ASWebAuthenticationSession redirect', () async {
    List<Object?>? received;
    mockHostApi('authorizeApple', (args) async {
      received = args;
      final url = Uri.parse(args[0]! as String);
      expect(url.queryParameters['client_id'], 'client-1');
      expect(url.queryParameters['state'], 'state-1');
      return 'com.example.app://callback?code=code-1&state=state-1';
    });

    final resp = await OidcDarwin().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(),
      const {},
    );

    expect(resp, isNotNull);
    expect(resp!.code, 'code-1');
    expect(resp.state, 'state-1');
    // args: [url, redirectUri, callbackScheme, preferEphemeral, options].
    expect(received![2], 'com.example.app');
    // Full redirectUri is sent so the native iOS 17.4+ .https Callback branch
    // can derive host/path for Universal-Link redirects.
    expect(received![1], 'com.example.app://callback');
    // default external user agent is non-ephemeral.
    expect(received![3], false);
  });

  test(
    'passes preferEphemeral=true for the ephemeral external user agent',
    () async {
      List<Object?>? received;
      mockHostApi('authorizeApple', (args) async {
        received = args;
        return 'com.example.app://callback?code=c&state=state-1';
      });

      await OidcDarwin().getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(
          ios: OidcNativeOptionsApple(prefersEphemeralWebBrowserSession: true),
        ),
        const {},
      );

      expect(received![3], true);
    },
  );

  test('reads the macos options field when running on macOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    List<Object?>? received;
    mockHostApi('authorizeApple', (args) async {
      received = args;
      return 'com.example.app://callback?code=c&state=state-1';
    });

    await OidcDarwin().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(
        macos: OidcNativeOptionsApple(prefersEphemeralWebBrowserSession: true),
      ),
      const {},
    );

    // preferEphemeral read from `.macos` (not `.ios`) on macOS.
    expect(received![3], true);
  });

  test('getAuthorizationResponse returns null on USER_CANCELLED', () async {
    mockHostApi('authorizeApple', (args) async {
      throw PlatformException(code: 'USER_CANCELLED', message: 'cancelled');
    });

    final resp = await OidcDarwin().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(),
      const {},
    );
    expect(resp, isNull);
  });

  test('getEndSessionResponse parses the post-logout redirect state', () async {
    mockHostApi('endSessionApple', (args) async {
      return 'com.example.app://logout?state=logout-state';
    });

    final resp = await OidcDarwin().getEndSessionResponse(
      metadata,
      OidcEndSessionRequest(
        postLogoutRedirectUri: Uri.parse('com.example.app://logout'),
        state: 'logout-state',
      ),
      const OidcPlatformSpecificOptions(),
      const {},
    );

    expect(resp, isNotNull);
    expect(resp!.state, 'logout-state');
  });

  test('getEndSessionResponse treats PRESENTATION_CONTEXT_INVALID (the '
      'iOS + Azure "-3" case) as a closed session (null)', () async {
    mockHostApi('endSessionApple', (args) async {
      throw PlatformException(
        code: 'PRESENTATION_CONTEXT_INVALID',
        message: '-3',
      );
    });

    final resp = await OidcDarwin().getEndSessionResponse(
      metadata,
      OidcEndSessionRequest(
        postLogoutRedirectUri: Uri.parse('com.example.app://logout'),
        state: 'logout-state',
      ),
      const OidcPlatformSpecificOptions(),
      const {},
    );
    expect(resp, isNull);
  });

  test('wraps a raw MissingPluginException (no plugin registered) as '
      'OidcException', () async {
    await expectLater(
      OidcDarwin(hostApi: _MissingPluginHostApi()).getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(),
        const {},
      ),
      throwsA(
        isA<OidcException>().having(
          (e) => e.message,
          'message',
          contains('not available on this platform'),
        ),
      ),
    );
  });

  test(
    'rethrows any other PlatformException code wrapped as OidcException',
    () async {
      mockHostApi('authorizeApple', (args) async {
        throw PlatformException(code: 'SOME_OTHER_ERROR', message: 'boom');
      });

      await expectLater(
        OidcDarwin().getAuthorizationResponse(
          metadata,
          _authRequest(),
          const OidcPlatformSpecificOptions(),
          const {},
        ),
        throwsA(
          isA<OidcException>().having(
            (e) => e.message,
            'message',
            allOf(contains('SOME_OTHER_ERROR'), contains('boom')),
          ),
        ),
      );
    },
  );

  group('nativeBrowserEvents', () {
    const eventChannel = EventChannel(
      'dev.flutter.pigeon.oidc_platform_interface.OidcNativeEventApi'
      '.streamNativeEvents',
    );

    tearDown(() => messenger.setMockStreamHandler(eventChannel, null));

    test('maps native event maps into typed OidcNativeBrowserEvents, dropping '
        'unrecognized event types', () async {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events
              ..success({
                'type': 'redirectReceived',
                'flowId': 'flow-1',
                'scheme': 'com.example.app',
                'host': 'callback',
                'hasCode': true,
                'hasState': true,
                'hasError': false,
              })
              // Forward-compatibility: an unrecognized type must be
              // dropped, not surfaced or thrown.
              ..success({'type': 'some-future-event-type'})
              ..endOfStream();
          },
        ),
      );

      final events = await OidcDarwin().nativeBrowserEvents().toList();

      expect(events, hasLength(1));
      final event = events.single as OidcBrowserRedirectReceivedEvent;
      expect(event.flowId, 'flow-1');
      expect(event.scheme, 'com.example.app');
      expect(event.host, 'callback');
      expect(event.hasCode, isTrue);
      expect(event.hasState, isTrue);
      expect(event.hasError, isFalse);
    });
  });
}
