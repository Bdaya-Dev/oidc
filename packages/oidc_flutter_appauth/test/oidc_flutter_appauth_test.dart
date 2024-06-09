// ignore_for_file: prefer_const_constructors, lines_longer_than_80_chars

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_flutter_appauth/oidc_flutter_appauth.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

import 'duende_discovery.dart';

class MockAppAuthImpl extends OidcPlatform with OidcFlutterAppauth {
  MockAppAuthImpl({
    required this.allowInsecureConnections,
    required this.preferEphemeralSession,
  });

  final bool allowInsecureConnections;
  final bool preferEphemeralSession;

  @override
  bool getAllowInsecureConnections(
    OidcPlatformSpecificOptions options,
  ) {
    return allowInsecureConnections;
  }

  @override
  bool getPreferEphemeralSession(OidcPlatformSpecificOptions options) {
    return preferEphemeralSession;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OidcFlutterAppauth', () {
    late MockAppAuthImpl oidc;

    const methodChannel =
        MethodChannel('crossingthestreams.io/flutter_appauth');
    const mockAuthResponse = {
      'authorizationCode': '1234',
      'codeVerifier': '12344321',
      'nonce': 'abcd',
      'authorizationAdditionalParameters': {
        'hello': 'world',
      },
    };

    final metadata = OidcProviderMetadata.fromJson(testDiscoveryRaw);
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (methodCall) async {
        switch (methodCall.method) {
          case 'authorize':
            return mockAuthResponse;
          default:
            throw UnimplementedError();
        }
      });
    });
    for (final preferEphemeralSession in [true, false]) {
      group('(preferEphemeralSession: $preferEphemeralSession)', () {
        for (final allowInsecureConnections in [true, false]) {
          group('(allowInsecureConnections: $allowInsecureConnections)', () {
            setUp(() {
              oidc = MockAppAuthImpl(
                allowInsecureConnections: allowInsecureConnections,
                preferEphemeralSession: preferEphemeralSession,
              );
            });

            test('create', () {
              expect(oidc, isNotNull);
            });

            test('getAuthorizationResponse', () async {
              final response = await oidc.getAuthorizationResponse(
                metadata,
                OidcAuthorizeRequest(
                  responseType: ['code'],
                  clientId: 'someClientId',
                  redirectUri: Uri.parse('hello:/world'),
                  scope: ['openid'],
                ),
                const OidcPlatformSpecificOptions(),
                {},
              );
              expect(response, isNotNull);
              expect(response!.code, mockAuthResponse['authorizationCode']);
              expect(response.codeVerifier, mockAuthResponse['codeVerifier']);
              expect(response.nonce, mockAuthResponse['nonce']);
              expect(
                response.src['hello'],
                (mockAuthResponse['authorizationAdditionalParameters']
                    as Map<String, dynamic>?)?['hello'],
              );
            });
          });
        }
      });
    }
  });
}
