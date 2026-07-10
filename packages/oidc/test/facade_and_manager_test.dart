// ignore_for_file: prefer_single_quotes

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oidc/oidc.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mock_client.dart';

class MockOidcPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements OidcPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOidcPlatform oidcPlatform;

  const clientCredentials = OidcClientAuthentication.none(
    clientId: 'my_client_id',
  );
  final settings = OidcUserManagerSettings(
    redirectUri: Uri.parse('http://example.com/redirect.html'),
  );
  final managerKeyStore = JsonWebKeyStore()..addKey(mockSigningKey);
  final doc = OidcProviderMetadata.fromJson(mockProviderMetadata);

  final authorizeRequest = OidcAuthorizeRequest(
    clientId: 'my_client_id',
    redirectUri: Uri.parse('http://example.com/redirect.html'),
    scope: [OidcConstants_Scopes.openid],
    responseType: [OidcConstants_AuthorizationEndpoint_ResponseType.code],
  );
  final endSessionRequest = OidcEndSessionRequest(
    clientId: 'my_client_id',
    postLogoutRedirectUri: Uri.parse('http://example.com/redirect.html'),
  );
  const platformOptions = OidcPlatformSpecificOptions();

  setUp(() {
    oidcPlatform = MockOidcPlatform();
    when(
      oidcPlatform.nativeBrowserEvents,
    ).thenAnswer((_) => const Stream.empty());
    OidcPlatform.instance = oidcPlatform;
  });

  group('OidcFlutter facade', () {
    test('prepareForRedirectFlow returns whatever the platform returns', () {
      when(
        () => oidcPlatform.prepareForRedirectFlow(platformOptions),
      ).thenReturn({'prepared': true});

      final result = OidcFlutter.prepareForRedirectFlow(platformOptions);

      expect(result, {'prepared': true});
      verify(
        () => oidcPlatform.prepareForRedirectFlow(platformOptions),
      ).called(1);
    });

    test(
      'getPlatformAuthorizationResponse returns the platform response',
      () async {
        final response = OidcAuthorizeResponse(
          src: const {'code': 'abc'},
          code: 'abc',
        );
        when(
          () => oidcPlatform.getAuthorizationResponse(
            doc,
            authorizeRequest,
            platformOptions,
            const {},
          ),
        ).thenAnswer((_) async => response);

        final result = await OidcFlutter.getPlatformAuthorizationResponse(
          metadata: doc,
          request: authorizeRequest,
        );

        expect(result, same(response));
      },
    );

    test(
      'getPlatformAuthorizationResponse rethrows OidcException unchanged',
      () async {
        const original = OidcException('native failure');
        when(
          () => oidcPlatform.getAuthorizationResponse(
            doc,
            authorizeRequest,
            platformOptions,
            const {},
          ),
        ).thenThrow(original);

        await expectLater(
          () => OidcFlutter.getPlatformAuthorizationResponse(
            metadata: doc,
            request: authorizeRequest,
          ),
          throwsA(same(original)),
        );
      },
    );

    test(
      'getPlatformAuthorizationResponse wraps a non-OidcException failure',
      () async {
        final original = StateError('boom');
        when(
          () => oidcPlatform.getAuthorizationResponse(
            doc,
            authorizeRequest,
            platformOptions,
            const {},
          ),
        ).thenThrow(original);

        await expectLater(
          () => OidcFlutter.getPlatformAuthorizationResponse(
            metadata: doc,
            request: authorizeRequest,
          ),
          throwsA(
            isA<OidcException>()
                .having((e) => e.message, 'message', 'Failed to authorize user')
                .having(
                  (e) => e.internalException,
                  'internalException',
                  same(original),
                ),
          ),
        );
      },
    );

    test(
      'getPlatformEndSessionResponse returns the platform response',
      () async {
        final response = OidcEndSessionResponse.fromJson({'state': 's1'});
        when(
          () => oidcPlatform.getEndSessionResponse(
            doc,
            endSessionRequest,
            platformOptions,
            const {},
          ),
        ).thenAnswer((_) async => response);

        final result = await OidcFlutter.getPlatformEndSessionResponse(
          metadata: doc,
          request: endSessionRequest,
          preparationResult: const {},
        );

        expect(result, same(response));
      },
    );

    test(
      'getPlatformEndSessionResponse wraps any failure into an OidcException',
      () async {
        final original = StateError('logout boom');
        when(
          () => oidcPlatform.getEndSessionResponse(
            doc,
            endSessionRequest,
            platformOptions,
            const {},
          ),
        ).thenThrow(original);

        await expectLater(
          () => OidcFlutter.getPlatformEndSessionResponse(
            metadata: doc,
            request: endSessionRequest,
            preparationResult: const {},
          ),
          throwsA(
            isA<OidcException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Failed to end user session',
                )
                .having(
                  (e) => e.internalException,
                  'internalException',
                  same(original),
                ),
          ),
        );
      },
    );

    test(
      'listenToFrontChannelLogoutRequests streams events from the platform',
      () async {
        final incoming = OidcFrontChannelLogoutIncomingRequest.fromJson({
          'iss': 'http://server.example.com',
          'sid': 'session-1',
        });
        final listenTo = Uri.parse('http://example.com/front-channel');
        const options = OidcFrontChannelRequestListeningOptions();
        when(
          () => oidcPlatform.listenToFrontChannelLogoutRequests(
            listenTo,
            options,
          ),
        ).thenAnswer((_) => Stream.value(incoming));

        final stream = OidcFlutter.listenToFrontChannelLogoutRequests(
          listenTo: listenTo,
        );

        await expectLater(stream, emits(same(incoming)));
      },
    );

    test('monitorSessionStatus streams events from the platform', () async {
      const result = OidcValidMonitorSessionResult(changed: true);
      final checkSessionIframe = Uri.parse(
        'http://server.example.com/check-session',
      );
      const request = OidcMonitorSessionStatusRequest(
        clientId: 'my_client_id',
        sessionState: 'session-state',
        interval: Duration(seconds: 5),
      );
      when(
        () => oidcPlatform.monitorSessionStatus(
          checkSessionIframe: checkSessionIframe,
          request: request,
        ),
      ).thenAnswer((_) => Stream.value(result));

      final stream = OidcFlutter.monitorSessionStatus(
        checkSessionIframe: checkSessionIframe,
        request: request,
      );

      await expectLater(stream, emits(same(result)));
    });

    test('nativeBrowserEvents streams events from the platform', () async {
      final event = OidcBrowserOpeningEvent(at: DateTime.now());
      when(
        oidcPlatform.nativeBrowserEvents,
      ).thenAnswer((_) => Stream.value(event));

      await expectLater(OidcFlutter.nativeBrowserEvents(), emits(same(event)));
    });
  });

  group('OidcUserManager platform delegation', () {
    late OidcUserManager manager;

    setUp(() {
      manager = OidcUserManager(
        discoveryDocument: doc,
        clientCredentials: clientCredentials,
        store: OidcMemoryStore(),
        settings: settings,
        httpClient: createMockOidcClient(),
        keyStore: managerKeyStore,
      );
    });

    test('isWeb reflects the current platform (false under flutter test)', () {
      expect(manager.isWeb, isFalse);
    });

    test('getAuthorizationResponse delegates to the platform', () async {
      final response = OidcAuthorizeResponse(
        src: const {'code': 'xyz'},
        code: 'xyz',
      );
      when(
        () => oidcPlatform.getAuthorizationResponse(
          doc,
          authorizeRequest,
          platformOptions,
          const {},
        ),
      ).thenAnswer((_) async => response);

      final result = await manager.getAuthorizationResponse(
        doc,
        authorizeRequest,
        platformOptions,
        const {},
      );

      expect(result, same(response));
    });

    test('getEndSessionResponse delegates to the platform', () async {
      final response = OidcEndSessionResponse.fromJson({'state': 's2'});
      when(
        () => oidcPlatform.getEndSessionResponse(
          doc,
          endSessionRequest,
          platformOptions,
          const {},
        ),
      ).thenAnswer((_) async => response);

      final result = await manager.getEndSessionResponse(
        doc,
        endSessionRequest,
        platformOptions,
        const {},
      );

      expect(result, same(response));
    });

    test(
      'listenToFrontChannelLogoutRequests delegates to the platform',
      () async {
        final incoming = OidcFrontChannelLogoutIncomingRequest.fromJson({
          'iss': 'http://server.example.com',
          'sid': 'session-2',
        });
        final listenTo = Uri.parse('http://example.com/front-channel-2');
        const options = OidcFrontChannelRequestListeningOptions();
        when(
          () => oidcPlatform.listenToFrontChannelLogoutRequests(
            listenTo,
            options,
          ),
        ).thenAnswer((_) => Stream.value(incoming));

        final stream = manager.listenToFrontChannelLogoutRequests(
          listenTo,
          options,
        );

        await expectLater(stream, emits(same(incoming)));
      },
    );

    test('monitorSessionStatus delegates to the platform', () async {
      const result = OidcValidMonitorSessionResult(changed: false);
      final checkSessionIframe = Uri.parse(
        'http://server.example.com/check-session-2',
      );
      const request = OidcMonitorSessionStatusRequest(
        clientId: 'my_client_id',
        sessionState: 'session-state-2',
        interval: Duration(seconds: 10),
      );
      when(
        () => oidcPlatform.monitorSessionStatus(
          checkSessionIframe: checkSessionIframe,
          request: request,
        ),
      ).thenAnswer((_) => Stream.value(result));

      final stream = manager.monitorSessionStatus(
        checkSessionIframe: checkSessionIframe,
        request: request,
      );

      await expectLater(stream, emits(same(result)));
    });

    test('prepareForRedirectFlow delegates to the platform', () {
      when(
        () => oidcPlatform.prepareForRedirectFlow(platformOptions),
      ).thenReturn({'ready': true});

      final result = manager.prepareForRedirectFlow(platformOptions);

      expect(result, {'ready': true});
    });

    test(
      'listenToNativeBrowserEvents delegates to the platform stream',
      () async {
        final event = OidcBrowserFlowCancelledEvent(at: DateTime.now());
        when(
          oidcPlatform.nativeBrowserEvents,
        ).thenAnswer((_) => Stream.value(event));

        await expectLater(
          manager.listenToNativeBrowserEvents(),
          emits(same(event)),
        );
      },
    );
  });
}
