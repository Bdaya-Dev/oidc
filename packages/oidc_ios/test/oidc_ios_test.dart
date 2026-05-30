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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final metadata = OidcProviderMetadata.fromJson(const {
    'issuer': 'https://op.example.com',
    'authorization_endpoint': 'https://op.example.com/authorize',
    'token_endpoint': 'https://op.example.com/token',
    'end_session_endpoint': 'https://op.example.com/logout',
  });

  tearDown(() => messenger.setMockMethodCallHandler(OidcIOS.channel, null));

  test('can be registered', () {
    OidcIOS.registerWith();
    expect(OidcPlatform.instance, isA<OidcIOS>());
  });

  test('uses the domain-prefixed channel name (must match native)', () {
    expect(OidcIOS.channel.name, OidcNativeChannels.ios);
    expect(OidcNativeChannels.ios, 'com.bdayadev.oidc/ios');
  });

  test(
    'wraps MissingPluginException (native plugin absent) as OidcException',
    () async {
      // With no mock handler registered, invokeMethod throws
      // MissingPluginException — the code must surface a clear OidcException.
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
    Map<Object?, Object?>? received;
    messenger.setMockMethodCallHandler(OidcIOS.channel, (call) async {
      expect(call.method, 'authorize');
      received = call.arguments as Map<Object?, Object?>;
      final url = Uri.parse(received!['url']! as String);
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
    expect(received!['callbackScheme'], 'com.example.app');
    // Full redirectUri is sent so the native iOS 17.4+ .https Callback branch
    // can derive host/path for Universal-Link redirects.
    expect(received!['redirectUri'], 'com.example.app://callback');
    // default external user agent is non-ephemeral.
    expect(received!['preferEphemeral'], false);
  });

  test(
    'passes preferEphemeral=true for the ephemeral external user agent',
    () async {
      Map<Object?, Object?>? received;
      messenger.setMockMethodCallHandler(OidcIOS.channel, (call) async {
        received = call.arguments as Map<Object?, Object?>;
        return 'com.example.app://callback?code=c&state=state-1';
      });

      await OidcIOS().getAuthorizationResponse(
        metadata,
        _authRequest(),
        const OidcPlatformSpecificOptions(
          ios: OidcPlatformSpecificOptions_AppAuth_IosMacos(
            externalUserAgent: OidcAppAuthExternalUserAgent
                .ephemeralAsWebAuthenticationSession,
          ),
        ),
        const {},
      );

      expect(received!['preferEphemeral'], true);
    },
  );

  test('getAuthorizationResponse returns null on USER_CANCELLED', () async {
    messenger.setMockMethodCallHandler(OidcIOS.channel, (call) async {
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
    messenger.setMockMethodCallHandler(OidcIOS.channel, (call) async {
      expect(call.method, 'endSession');
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
    messenger.setMockMethodCallHandler(OidcIOS.channel, (call) async {
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
