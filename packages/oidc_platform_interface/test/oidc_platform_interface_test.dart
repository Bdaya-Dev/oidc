import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A fake [OidcPlatform] implementation, following the
/// `plugin_platform_interface` mock-platform pattern: it must call
/// `PlatformInterface.verifyToken` against the base class's protected token
/// via `MockPlatformInterfaceMixin`, otherwise `OidcPlatform.instance = ...`
/// throws.
class _FakeOidcPlatform extends OidcPlatform with MockPlatformInterfaceMixin {
  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) {
    return {'prepared': true};
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    return null;
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    return null;
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    return const Stream.empty();
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    return const Stream.empty();
  }
}

/// A type that does *not* extend [OidcPlatform] via the token mechanism, used
/// to prove `PlatformInterface.verify` actually gates the setter.
class _UnverifiedOidcPlatform implements OidcPlatform {
  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) =>
      throw UnimplementedError();

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) =>
      throw UnimplementedError();

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) =>
      throw UnimplementedError();

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) =>
          throw UnimplementedError();

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) =>
      throw UnimplementedError();

  @override
  Stream<OidcNativeBrowserEvent> nativeBrowserEvents() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final metadata = OidcProviderMetadata.fromJson(const {});
  final authorizeRequest = OidcAuthorizeRequest(
    responseType: const ['code'],
    clientId: 'client',
    redirectUri: Uri.parse('https://example.com/cb'),
    scope: const ['openid'],
  );
  const endSessionRequest = OidcEndSessionRequest();
  const platformOptions = OidcPlatformSpecificOptions();
  const frontChannelOptions = OidcFrontChannelRequestListeningOptions();
  const monitorRequest = OidcMonitorSessionStatusRequest(
    clientId: 'client',
    sessionState: 'state',
    interval: Duration(seconds: 1),
  );

  group('OidcPlatform.instance', () {
    test('defaults to a NoOpOidcPlatform', () {
      // Reset in case a previous test in this process replaced it.
      OidcPlatform.instance = NoOpOidcPlatform();
      expect(OidcPlatform.instance, isA<NoOpOidcPlatform>());
    });

    test('setter replaces the singleton with a verified platform', () {
      final fake = _FakeOidcPlatform();
      OidcPlatform.instance = fake;
      expect(OidcPlatform.instance, same(fake));
      expect(
        OidcPlatform.instance.prepareForRedirectFlow(platformOptions),
        {'prepared': true},
      );
      // restore default for other tests in this file.
      OidcPlatform.instance = NoOpOidcPlatform();
    });

    test(
      'setter throws AssertionError for a platform not built on the token',
      () {
        expect(
          () => OidcPlatform.instance = _UnverifiedOidcPlatform(),
          throwsAssertionError,
        );
        // The singleton must remain unchanged after a rejected assignment.
        expect(OidcPlatform.instance, isNot(isA<_UnverifiedOidcPlatform>()));
      },
    );

    test('nativeBrowserEvents() default implementation is an empty stream',
        () async {
      final fake = _FakeOidcPlatform();
      final events = await fake.nativeBrowserEvents().toList();
      expect(events, isEmpty);
    });
  });

  group('NoOpOidcPlatform', () {
    late NoOpOidcPlatform platform;

    setUp(() {
      platform = NoOpOidcPlatform();
    });

    test('prepareForRedirectFlow throws UnimplementedError', () {
      expect(
        () => platform.prepareForRedirectFlow(platformOptions),
        throwsUnimplementedError,
      );
    });

    test('getAuthorizationResponse throws UnimplementedError', () {
      expect(
        () => platform.getAuthorizationResponse(
          metadata,
          authorizeRequest,
          platformOptions,
          const {},
        ),
        throwsUnimplementedError,
      );
    });

    test('getEndSessionResponse throws UnimplementedError', () {
      expect(
        () => platform.getEndSessionResponse(
          metadata,
          endSessionRequest,
          platformOptions,
          const {},
        ),
        throwsUnimplementedError,
      );
    });

    test('listenToFrontChannelLogoutRequests throws UnimplementedError', () {
      expect(
        () => platform.listenToFrontChannelLogoutRequests(
          Uri.parse('https://example.com'),
          frontChannelOptions,
        ),
        throwsUnimplementedError,
      );
    });

    test('monitorSessionStatus throws UnimplementedError', () {
      expect(
        () => platform.monitorSessionStatus(
          checkSessionIframe: Uri.parse('https://example.com/session'),
          request: monitorRequest,
        ),
        throwsUnimplementedError,
      );
    });

    test('nativeBrowserEvents falls back to the default empty stream',
        () async {
      final events = await platform.nativeBrowserEvents().toList();
      expect(events, isEmpty);
    });
  });
}
