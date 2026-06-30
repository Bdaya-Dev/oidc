// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/src/logger.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

class MockDesktopImpl extends OidcPlatform with OidcDesktop {
  MockDesktopImpl({
    this.successfulPageResponse,
    this.methodMismatchResponse,
    this.notFoundResponse,
    this.flowTimeoutSeconds,
    this.launchUrl,
  });

  final String? successfulPageResponse;
  final String? methodMismatchResponse;
  final String? notFoundResponse;
  final int? flowTimeoutSeconds;
  final Future<bool> Function(Uri url)? launchUrl;

  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) {
    return OidcPlatformSpecificOptions_Native(
      successfulPageResponse: successfulPageResponse,
      methodMismatchResponse: methodMismatchResponse,
      notFoundResponse: notFoundResponse,
      flowTimeoutSeconds: flowTimeoutSeconds,
      launchUrl: launchUrl,
    );
  }

  @override
  Logger get logger => Logger('Oidc.Mock');
}

final successfulPageResponseValues = [null, 'a'];
final methodMismatchResponseValues = [null, 'b'];
final notFoundResponseValues = [null, 'c'];
void main() {
  group('OidcDesktop', () {
    for (final successfulPageResponse in successfulPageResponseValues) {
      group('(successfulPageResponse: $successfulPageResponse)', () {
        for (final methodMismatchResponse in methodMismatchResponseValues) {
          group('(methodMismatchResponse: $methodMismatchResponse)', () {
            for (final notFoundResponse in notFoundResponseValues) {
              group('(notFoundResponse: $notFoundResponse)', () {
                final oidc = MockDesktopImpl(
                  methodMismatchResponse: methodMismatchResponse,
                  notFoundResponse: notFoundResponse,
                  successfulPageResponse: successfulPageResponse,
                );
                test('can be instantiated', () {
                  expect(oidc, isNotNull);
                });
                test('getAuthorizationResponse', () {
                  // oidc.getAuthorizationResponse(
                  //   metadata,
                  //   request,
                  //   options,
                  // );
                });
              });
            }
          });
        }
      });
    }

    test(
      'getAuthorizationResponse throws a timeout OidcException when no '
      'redirect arrives within flowTimeoutSeconds',
      () async {
        final oidc = MockDesktopImpl(
          flowTimeoutSeconds: 1,
          // Bypass url_launcher so no real browser opens.
          launchUrl: (uri) async => true,
        );
        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          // Loopback redirect on an ephemeral port (0 => any free port).
          redirectUri: Uri(scheme: 'http', host: '127.0.0.1', port: 0),
          scope: const ['openid'],
        );

        await expectLater(
          oidc.getAuthorizationResponse(
            metadata,
            request,
            const OidcPlatformSpecificOptions(),
            const {},
          ),
          throwsA(
            isA<OidcException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
      },
    );
  });
}
