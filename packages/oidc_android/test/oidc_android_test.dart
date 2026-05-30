import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_android/oidc_android.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

OidcAuthorizeRequest _authRequest() => OidcAuthorizeRequest(
      clientId: 'client-1',
      redirectUri: Uri.parse('com.example.app://callback'),
      responseType: const [
        OidcConstants_AuthorizationEndpoint_ResponseType.code,
      ],
      scope: const ['openid'],
      state: 'state-1',
    );

/// Base Pigeon channel name for [OidcAndroidHostApi] (must match the native
/// Kotlin `OidcAndroidHostApi.setUp` registration).
const _hostApiPrefix =
    'dev.flutter.pigeon.oidc_platform_interface.OidcAndroidHostApi';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = OidcAndroidHostApi.pigeonChannelCodec;

  /// Mocks a native [OidcAndroidHostApi] method at the Pigeon channel level:
  /// decodes the positional argument list, and replies with either a single
  /// success value or — when [handler] throws a [PlatformException] — the
  /// Pigeon 3-element error envelope `[code, message, details]`.
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
    for (final method in ['authorize', 'endSession', 'cancel']) {
      messenger.setMockMessageHandler('$_hostApiPrefix.$method', null);
    }
  });

  test('can be registered', () {
    OidcAndroid.registerWith();
    expect(OidcPlatform.instance, isA<OidcAndroid>());
  });

  test('forwards serialized Custom Tabs options over the Pigeon channel',
      () async {
    List<Object?>? received;
    mockHostApi('authorize', (args) async {
      received = args;
      return 'com.example.app://callback?code=c&state=state-1';
    });

    await OidcAndroid().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(
        android: OidcNativeOptionsAndroid(
          showTitle: false,
          urlBarHidingEnabled: true,
          ephemeralBrowsing: true,
          shareState: OidcCustomTabsShareState.off,
          colorSchemes: OidcCustomTabsColorSchemes(
            colorScheme: OidcColorScheme.dark,
            defaultParams: OidcColorSchemeParams(toolbarColor: 0xFF2196F3),
          ),
        ),
      ),
      const {},
    );

    // Pigeon authorize args: [url, redirectUri, callbackScheme, options].
    final opts = received![3]! as Map<Object?, Object?>;
    expect(opts['showTitle'], false);
    expect(opts['urlBarHidingEnabled'], true);
    expect(opts['ephemeralBrowsing'], true);
    // Enums serialize by name; colors as ARGB ints; nested objects as maps.
    expect(opts['shareState'], 'off');
    final schemes = opts['colorSchemes']! as Map<Object?, Object?>;
    expect(schemes['colorScheme'], 'dark');
    final params = schemes['defaultParams']! as Map<Object?, Object?>;
    expect(params['toolbarColor'], 0xFF2196F3);
  });

  test('wraps a missing native plugin (channel-error) as OidcException',
      () async {
    // With no mock handler registered, the Pigeon channel send returns a null
    // reply, which surfaces as a `channel-error` PlatformException; the code
    // must translate that into a clear OidcException.
    await expectLater(
      OidcAndroid().getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(),
        const {},
      ),
      throwsA(isA<OidcException>()),
    );
  });

  test(
      'getAuthorizationResponse builds the URL in Dart and parses the native '
      'redirect (the Custom Tabs primitive only opens the URL)', () async {
    List<Object?>? received;
    mockHostApi('authorize', (args) async {
      received = args;
      final url = Uri.parse(args[0]! as String);
      expect(url.queryParameters['client_id'], 'client-1');
      expect(url.queryParameters['state'], 'state-1');
      expect(url.queryParameters['response_type'], 'code');
      return 'com.example.app://callback?code=code-1&state=state-1';
    });

    final resp = await OidcAndroid().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(),
      const {},
    );

    expect(resp, isNotNull);
    expect(resp!.code, 'code-1');
    expect(resp.state, 'state-1');
    // args: [url, redirectUri, callbackScheme, options].
    expect(received![1], 'com.example.app://callback');
    expect(received![2], 'com.example.app');
  });

  test('getAuthorizationResponse returns null on USER_CANCELLED', () async {
    mockHostApi('authorize', (args) async {
      throw PlatformException(code: 'USER_CANCELLED', message: 'cancelled');
    });

    final resp = await OidcAndroid().getAuthorizationResponse(
      metadata,
      _authRequest(),
      const OidcPlatformSpecificOptions(),
      const {},
    );
    expect(resp, isNull);
  });

  test(
      'getAuthorizationResponse rethrows other native errors as '
      'OidcException', () async {
    mockHostApi('authorize', (args) async {
      throw PlatformException(code: 'PLATFORM_ERROR', message: 'boom');
    });

    await expectLater(
      OidcAndroid().getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(),
        const {},
      ),
      throwsA(isA<OidcException>()),
    );
  });

  test('getEndSessionResponse parses the post-logout redirect state', () async {
    mockHostApi('endSession', (args) async {
      return 'com.example.app://logout?state=logout-state';
    });

    final resp = await OidcAndroid().getEndSessionResponse(
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
}
