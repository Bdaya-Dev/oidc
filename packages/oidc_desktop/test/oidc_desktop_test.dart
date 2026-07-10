// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';

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

    test(
      'getAuthorizationResponse completes successfully when the loopback '
      'listener receives a matching GET redirect, and returns the '
      'configured successful page body to the caller',
      () async {
        String? receivedBody;
        int? receivedStatusCode;

        final oidc = MockDesktopImpl(
          successfulPageResponse: '<html>done</html>',
          launchUrl: (uri) async {
            final redirectUriString = uri.queryParameters['redirect_uri'];
            expect(redirectUriString, isNotNull);
            final redirectUri = Uri.parse(redirectUriString!);

            final client = HttpClient();
            try {
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-123',
                  'state': uri.queryParameters['state'] ?? '',
                },
              );
              final request = await client.getUrl(callbackUri);
              final response = await request.close();
              receivedStatusCode = response.statusCode;
              receivedBody = await response.transform(utf8.decoder).join();
            } finally {
              client.close(force: true);
            }
            return true;
          },
        );

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          redirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 0,
            path: '/callback',
          ),
          scope: const ['openid'],
        );

        final response = await oidc.getAuthorizationResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        );

        expect(receivedStatusCode, HttpStatus.ok);
        expect(receivedBody, '<html>done</html>');
        expect(response, isNotNull);
        expect(response!.code, 'auth-code-123');
      },
    );

    test(
      'the loopback listener responds 405 with the configured mismatch '
      'body to a non-GET request, then still completes the flow on a '
      'subsequent matching GET',
      () async {
        int? mismatchStatusCode;
        String? mismatchBody;

        final oidc = MockDesktopImpl(
          methodMismatchResponse: 'method-not-allowed-body',
          launchUrl: (uri) async {
            final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
            final client = HttpClient();
            try {
              // First: send a POST, which the listener should reject.
              final postRequest = await client.postUrl(redirectUri);
              final postResponse = await postRequest.close();
              mismatchStatusCode = postResponse.statusCode;
              mismatchBody = await postResponse.transform(utf8.decoder).join();

              // Then: send the matching GET so the flow can complete.
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-456',
                  'state': '',
                },
              );
              final getRequest = await client.getUrl(callbackUri);
              await (await getRequest.close()).drain<void>();
            } finally {
              client.close(force: true);
            }
            return true;
          },
        );

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          redirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 0,
            path: '/callback',
          ),
          scope: const ['openid'],
        );

        final response = await oidc.getAuthorizationResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        );

        expect(mismatchStatusCode, HttpStatus.methodNotAllowed);
        expect(mismatchBody, 'method-not-allowed-body');
        expect(response, isNotNull);
        expect(response!.code, 'auth-code-456');
      },
    );

    test(
      'the loopback listener responds 404 with the configured not-found '
      'body when the request path does not match the redirect path, then '
      'still completes the flow on a subsequent matching GET',
      () async {
        int? notFoundStatusCode;
        String? notFoundBody;

        final oidc = MockDesktopImpl(
          notFoundResponse: 'not-found-body',
          launchUrl: (uri) async {
            final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
            final client = HttpClient();
            try {
              // First: hit a path that does not match the configured one.
              final wrongPathUri = redirectUri.replace(path: '/wrong-path');
              final wrongRequest = await client.getUrl(wrongPathUri);
              final wrongResponse = await wrongRequest.close();
              notFoundStatusCode = wrongResponse.statusCode;
              notFoundBody = await wrongResponse.transform(utf8.decoder).join();

              // Then: send the matching GET so the flow can complete.
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-789',
                  'state': '',
                },
              );
              final getRequest = await client.getUrl(callbackUri);
              await (await getRequest.close()).drain<void>();
            } finally {
              client.close(force: true);
            }
            return true;
          },
        );

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          redirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 0,
            path: '/callback',
          ),
          scope: const ['openid'],
        );

        final response = await oidc.getAuthorizationResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        );

        expect(notFoundStatusCode, HttpStatus.notFound);
        expect(notFoundBody, 'not-found-body');
        expect(response, isNotNull);
        expect(response!.code, 'auth-code-789');
      },
    );

    test(
      'getAuthorizationResponse still completes the flow (and logs a '
      'warning) when the custom launchUrl callback reports a failed '
      'launch',
      () async {
        var launchAttempted = false;

        final oidc = MockDesktopImpl(
          launchUrl: (uri) async {
            launchAttempted = true;
            final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
            final client = HttpClient();
            try {
              final callbackUri = redirectUri.replace(
                queryParameters: {
                  ...redirectUri.queryParameters,
                  'code': 'auth-code-fallback',
                  'state': '',
                },
              );
              final getRequest = await client.getUrl(callbackUri);
              await (await getRequest.close()).drain<void>();
            } finally {
              client.close(force: true);
            }
            // Simulate a failed launch (e.g. no browser available).
            return false;
          },
        );

        final metadata = OidcProviderMetadata.fromJson({
          'issuer': 'https://op.example.com',
          'authorization_endpoint': 'https://op.example.com/authorize',
        });
        final request = OidcAuthorizeRequest(
          responseType: const ['code'],
          clientId: 'client-1',
          redirectUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 0,
            path: '/callback',
          ),
          scope: const ['openid'],
        );

        final response = await oidc.getAuthorizationResponse(
          metadata,
          request,
          const OidcPlatformSpecificOptions(),
          const {},
        );

        expect(launchAttempted, isTrue);
        expect(response, isNotNull);
        expect(response!.code, 'auth-code-fallback');
      },
    );
  });
}
