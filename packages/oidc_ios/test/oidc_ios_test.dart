import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_ios/oidc_ios.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

OidcAuthorizeRequest _authRequest() => OidcAuthorizeRequest(
  clientId: 'client-1',
  redirectUri: Uri.parse('com.example.app://callback'),
  responseType: const [OidcConstants_AuthorizationEndpoint_ResponseType.code],
  scope: const ['openid'],
  state: 'state-1',
);

/// Base Pigeon channel name for [OidcAppleHostApi] (must match the native Swift
/// `OidcAppleHostApiSetup.setUp` registration).
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
    OidcIOS.registerWith();
    expect(OidcPlatform.instance, isA<OidcIOS>());
  });

  test(
    'forwards apple options (callbackMode + additionalHeaderFields)',
    () async {
      List<Object?>? received;
      mockHostApi('authorizeApple', (args) async {
        received = args;
        return 'com.example.app://callback?code=c&state=state-1';
      });

      await OidcIOS().getAuthorizationResponse(
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

  test(
    'wraps a missing native plugin (channel-error) as OidcException',
    () async {
      await expectLater(
        OidcIOS().getAuthorizationResponse(
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

    final resp = await OidcIOS().getAuthorizationResponse(
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

      await OidcIOS().getAuthorizationResponse(
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

  test('getAuthorizationResponse returns null on USER_CANCELLED', () async {
    mockHostApi('authorizeApple', (args) async {
      throw PlatformException(code: 'USER_CANCELLED', message: 'cancelled');
    });

    final resp = await OidcIOS().getAuthorizationResponse(
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

    final resp = await OidcIOS().getEndSessionResponse(
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

    final resp = await OidcIOS().getEndSessionResponse(
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
}
