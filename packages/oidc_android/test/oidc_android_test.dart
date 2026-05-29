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

  tearDown(
    () => messenger.setMockMethodCallHandler(OidcAndroid.channel, null),
  );

  test('can be registered', () {
    OidcAndroid.registerWith();
    expect(OidcPlatform.instance, isA<OidcAndroid>());
  });

  test('getAuthorizationResponse builds the URL in Dart and parses the native '
      'redirect (the Custom Tabs primitive only opens the URL)', () async {
    Map<Object?, Object?>? received;
    messenger.setMockMethodCallHandler(OidcAndroid.channel, (call) async {
      expect(call.method, 'authorize');
      received = call.arguments as Map<Object?, Object?>;
      final url = Uri.parse(received!['url']! as String);
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
    expect(received!['callbackScheme'], 'com.example.app');
    expect(received!['redirectUri'], 'com.example.app://callback');
  });

  test('getAuthorizationResponse returns null on USER_CANCELLED', () async {
    messenger.setMockMethodCallHandler(OidcAndroid.channel, (call) async {
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

  test('getAuthorizationResponse rethrows other native errors as '
      'OidcException', () async {
    messenger.setMockMethodCallHandler(OidcAndroid.channel, (call) async {
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
    messenger.setMockMethodCallHandler(OidcAndroid.channel, (call) async {
      expect(call.method, 'endSession');
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
