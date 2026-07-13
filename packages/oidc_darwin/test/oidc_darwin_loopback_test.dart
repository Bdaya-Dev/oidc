// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_darwin/oidc_darwin.dart';

// These tests exercise the macOS `loopbackSystemBrowser` navigation mode, which
// runs entirely in Dart (system browser + `oidc_loopback_listener`) and never
// touches the Pigeon native channel. They therefore deliberately DO NOT call
// `TestWidgetsFlutterBinding.ensureInitialized()`: that binding installs an
// `HttpOverrides` that fakes every `HttpClient`, which would prevent the fake
// browser launcher below from reaching the real loopback `HttpServer`. The
// browser is faked through the `OidcNativeOptionsApple.launchUrl` seam, exactly
// like `oidc_desktop`'s tests fake `launchUrl`.
void main() {
  final metadata = OidcProviderMetadata.fromJson(const {
    'issuer': 'https://op.example.com',
    'authorization_endpoint': 'https://op.example.com/authorize',
    'token_endpoint': 'https://op.example.com/token',
    'end_session_endpoint': 'https://op.example.com/logout',
  });

  OidcAuthorizeRequest authRequest() => OidcAuthorizeRequest(
    clientId: 'client-1',
    // Loopback redirect on an ephemeral port (0 => any free port), as required
    // by RFC 8252 §7.3.
    redirectUri: Uri(scheme: 'http', host: '127.0.0.1', port: 0, path: '/cb'),
    responseType: const [OidcConstants_AuthorizationEndpoint_ResponseType.code],
    scope: const ['openid'],
    state: 'state-1',
  );

  group('macOS loopbackSystemBrowser navigation mode', () {
    setUp(() {
      // The mode is only honored on macOS.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'useLoopbackSystemBrowser is true on macOS when the macos options select '
      'the loopback mode, and false for the default mode / on iOS',
      () {
        final darwin = OidcDarwin();
        const loopback = OidcPlatformSpecificOptions(
          macos: OidcNativeOptionsApple(
            navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
          ),
        );

        expect(darwin.useLoopbackSystemBrowser(loopback), isTrue);
        // Default mode (ASWebAuthenticationSession) => false even on macOS.
        expect(
          darwin.useLoopbackSystemBrowser(const OidcPlatformSpecificOptions()),
          isFalse,
        );

        // Same loopback selection, but on iOS => ignored (false). The iOS
        // field carries the mode here to prove the platform gate, not the
        // field, is what disables it.
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(
          darwin.useLoopbackSystemBrowser(
            const OidcPlatformSpecificOptions(
              ios: OidcNativeOptionsApple(
                navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
              ),
            ),
          ),
          isFalse,
        );
      },
    );

    test('getAuthorizationResponse opens the system browser, captures the '
        'loopback redirect, and returns the parsed response with the '
        'configured success page written back to the browser', () async {
      String? receivedBody;
      int? receivedStatusCode;

      final response = await OidcDarwin().getAuthorizationResponse(
        metadata,
        authRequest(),
        OidcPlatformSpecificOptions(
          macos: OidcNativeOptionsApple(
            navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
            successfulPageResponse: '<html>done</html>',
            launchUrl: (uri) async {
              // The launched authorization URL must carry the port-rewritten
              // loopback redirect_uri.
              final redirectUriString = uri.queryParameters['redirect_uri'];
              expect(redirectUriString, isNotNull);
              final redirectUri = Uri.parse(redirectUriString!);
              expect(redirectUri.host, '127.0.0.1');
              expect(redirectUri.port, isNot(0));

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
                final res = await request.close();
                receivedStatusCode = res.statusCode;
                receivedBody = await res.transform(utf8.decoder).join();
              } finally {
                client.close(force: true);
              }
              return true;
            },
          ),
        ),
        const {},
      );

      expect(receivedStatusCode, HttpStatus.ok);
      expect(receivedBody, '<html>done</html>');
      expect(response, isNotNull);
      expect(response!.code, 'auth-code-123');
      expect(response.state, 'state-1');
    });

    test('getAuthorizationResponse throws a timeout OidcException when no '
        'redirect arrives within flowTimeoutSeconds', () async {
      await expectLater(
        OidcDarwin().getAuthorizationResponse(
          metadata,
          authRequest(),
          OidcPlatformSpecificOptions(
            macos: OidcNativeOptionsApple(
              navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
              flowTimeoutSeconds: 1,
              // Bypass url_launcher: pretend the browser opened but the user
              // never completes the flow.
              launchUrl: (uri) async => true,
            ),
          ),
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
    });

    test(
      'the loopback listener responds 405 with the configured mismatch body '
      'to a non-GET request, then still completes on a subsequent GET',
      () async {
        int? mismatchStatusCode;
        String? mismatchBody;

        final response = await OidcDarwin().getAuthorizationResponse(
          metadata,
          authRequest(),
          OidcPlatformSpecificOptions(
            macos: OidcNativeOptionsApple(
              navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
              methodMismatchResponse: 'method-not-allowed-body',
              launchUrl: (uri) async {
                final redirectUri = Uri.parse(
                  uri.queryParameters['redirect_uri']!,
                );
                final client = HttpClient();
                try {
                  // First: a POST, which the listener rejects with 405.
                  final postRequest = await client.postUrl(redirectUri);
                  final postResponse = await postRequest.close();
                  mismatchStatusCode = postResponse.statusCode;
                  mismatchBody = await postResponse
                      .transform(utf8.decoder)
                      .join();

                  // Then: the matching GET so the flow can complete.
                  final callbackUri = redirectUri.replace(
                    queryParameters: {
                      ...redirectUri.queryParameters,
                      'code': 'auth-code-456',
                      'state': 'state-1',
                    },
                  );
                  final getRequest = await client.getUrl(callbackUri);
                  await (await getRequest.close()).drain<void>();
                } finally {
                  client.close(force: true);
                }
                return true;
              },
            ),
          ),
          const {},
        );

        expect(mismatchStatusCode, HttpStatus.methodNotAllowed);
        expect(mismatchBody, 'method-not-allowed-body');
        expect(response, isNotNull);
        expect(response!.code, 'auth-code-456');
      },
    );

    test('getAuthorizationResponse still completes (via the timeout-free path) '
        'when the launcher reports a failed launch but the redirect still '
        'arrives', () async {
      var launchAttempted = false;

      final response = await OidcDarwin().getAuthorizationResponse(
        metadata,
        authRequest(),
        OidcPlatformSpecificOptions(
          macos: OidcNativeOptionsApple(
            navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
            launchUrl: (uri) async {
              launchAttempted = true;
              final redirectUri = Uri.parse(
                uri.queryParameters['redirect_uri']!,
              );
              final client = HttpClient();
              try {
                final callbackUri = redirectUri.replace(
                  queryParameters: {
                    ...redirectUri.queryParameters,
                    'code': 'auth-code-fallback',
                    'state': 'state-1',
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
          ),
        ),
        const {},
      );

      expect(launchAttempted, isTrue);
      expect(response, isNotNull);
      expect(response!.code, 'auth-code-fallback');
    });

    test(
      'getEndSessionResponse runs the loopback flow and parses the state from '
      'the post-logout redirect',
      () async {
        final response = await OidcDarwin().getEndSessionResponse(
          metadata,
          OidcEndSessionRequest(
            postLogoutRedirectUri: Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: 0,
              path: '/post-logout',
            ),
          ),
          OidcPlatformSpecificOptions(
            macos: OidcNativeOptionsApple(
              navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
              launchUrl: (uri) async {
                final redirectUri = Uri.parse(
                  uri.queryParameters['post_logout_redirect_uri']!,
                );
                final client = HttpClient();
                try {
                  final callbackUri = redirectUri.replace(
                    queryParameters: {
                      ...redirectUri.queryParameters,
                      'state': 'logout-state-1',
                    },
                  );
                  final getRequest = await client.getUrl(callbackUri);
                  await (await getRequest.close()).drain<void>();
                } finally {
                  client.close(force: true);
                }
                return true;
              },
            ),
          ),
          const {},
        );

        expect(response, isNotNull);
        expect(response!.state, 'logout-state-1');
      },
    );

    test(
      'getEndSessionResponse returns null without launching a browser when the '
      'request has no postLogoutRedirectUri',
      () async {
        var launchAttempted = false;
        final response = await OidcDarwin().getEndSessionResponse(
          metadata,
          const OidcEndSessionRequest(),
          OidcPlatformSpecificOptions(
            macos: OidcNativeOptionsApple(
              navigationMode: OidcAppleNavigationMode.loopbackSystemBrowser,
              launchUrl: (uri) async {
                launchAttempted = true;
                return true;
              },
            ),
          ),
          const {},
        );

        expect(response, isNull);
        expect(launchAttempted, isFalse);
      },
    );
  });
}
