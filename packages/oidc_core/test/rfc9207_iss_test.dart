@TestOn('vm')
library;

import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

Uri _cb(Map<String, String> params) =>
    Uri.parse('https://app.example.com/cb').replace(queryParameters: params);

final _issuer = Uri.parse('https://op.example.com');

/// Minimal concrete manager for driving [OidcUserManagerBase.tryGetAuthResponse]
/// (via [OidcUserManagerBase.loginAuthorizationCodeFlow]) in a VM test.
///
/// [getAuthorizationResponse] simulates a platform channel that returns an
/// authorization ERROR response without doing any `iss` validation of its
/// own — exactly like a native platform's raw callback parsing — so the test
/// exercises the manager-level RFC 9207 defense in `tryGetAuthResponse`'s
/// catch block, independent of [OidcEndpoints.parseAuthorizeResponse].
class _TestManager extends OidcUserManagerBase {
  _TestManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    required this.buildErrorResponse,
    super.httpClient,
  });

  final OidcErrorResponse Function(String? state) buildErrorResponse;

  @override
  bool get isWeb => false;
  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async {
    throw OidcException.serverError(
      errorResponse: buildErrorResponse(request.state),
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
    Map<String, dynamic> preparationResult,
  ) async => null;
  @override
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions options,
  ) => const {};
  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) => const Stream.empty();
  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) => const Stream.empty();
}

OidcProviderMetadata _metadata({required bool issSupported}) =>
    OidcProviderMetadata.fromJson({
      'issuer': _issuer.toString(),
      'authorization_endpoint': 'https://op.example.com/authorize',
      'token_endpoint': 'https://op.example.com/token',
      if (issSupported) 'authorization_response_iss_parameter_supported': true,
    });

Future<_TestManager> _buildManager({
  required bool issSupported,
  required OidcErrorResponse Function(String? state) buildErrorResponse,
}) async {
  final manager = _TestManager(
    discoveryDocument: _metadata(issSupported: issSupported),
    clientCredentials: const OidcClientAuthentication.none(
      clientId: 'client-1',
    ),
    store: OidcMemoryStore(),
    httpClient: MockClient(
      (_) async => throw UnimplementedError('no HTTP calls expected'),
    ),
    settings: OidcUserManagerSettings(
      redirectUri: Uri.parse('com.example.app://cb'),
      strictJwtVerification: false,
    ),
    buildErrorResponse: buildErrorResponse,
  );
  await manager.init();
  return manager;
}

void main() {
  group('RFC 9207 authorization-response iss validation', () {
    test('require-when-advertised: missing iss is rejected', () async {
      await expectLater(
        OidcEndpoints.parseAuthorizeResponse(
          responseUri: _cb({'code': 'c', 'state': 's'}),
          expectedIssuer: _issuer,
          requireIss: true,
        ),
        throwsA(isA<OidcException>()),
        reason: 'an AS advertising iss support MUST send iss (§2.4)',
      );
    });

    test('present-but-mismatched iss is rejected (mix-up defense)', () async {
      await expectLater(
        OidcEndpoints.parseAuthorizeResponse(
          responseUri: _cb({
            'code': 'c',
            'state': 's',
            'iss': 'https://attacker.example',
          }),
          expectedIssuer: _issuer,
          requireIss: true,
        ),
        throwsA(
          predicate(
            (e) => e is OidcException && e.toString().contains('mix-up'),
          ),
        ),
      );
    });

    test('matching iss is accepted', () async {
      final resp = await OidcEndpoints.parseAuthorizeResponse(
        responseUri: _cb({
          'code': 'c',
          'state': 's',
          'iss': 'https://op.example.com',
        }),
        expectedIssuer: _issuer,
        requireIss: true,
      );
      expect(resp.code, 'c');
      expect(resp.iss, _issuer);
    });

    test(
      'iss is validated on an ERROR redirect BEFORE the server-error throw',
      () async {
        await expectLater(
          OidcEndpoints.parseAuthorizeResponse(
            responseUri: _cb({
              'error': 'access_denied',
              'iss': 'https://attacker.example',
            }),
            expectedIssuer: _issuer,
            requireIss: true,
          ),
          throwsA(
            predicate(
              // the iss/mix-up error, NOT the server-error for access_denied
              (e) => e is OidcException && e.toString().contains('mix-up'),
            ),
          ),
        );
      },
    );

    test('lenient: requireIss=false + missing iss is accepted', () async {
      final resp = await OidcEndpoints.parseAuthorizeResponse(
        responseUri: _cb({'code': 'c', 'state': 's'}),
        expectedIssuer: _issuer,
      );
      expect(resp.code, 'c');
    });

    test(
      'error response still surfaces serverError when iss is fine (requireIss=false)',
      () async {
        await expectLater(
          OidcEndpoints.parseAuthorizeResponse(
            responseUri: _cb({'error': 'access_denied'}),
          ),
          throwsA(isA<OidcException>()),
        );
      },
    );
  });

  group(
    'manager-level: iss is validated on the authorization ERROR path '
    '(tryGetAuthResponse catch block, independent of parseAuthorizeResponse)',
    () {
      test(
        'require-when-advertised: an error response missing iss is rejected '
        'as a mix-up, not surfaced as the original server error',
        () async {
          final manager = await _buildManager(
            issSupported: true,
            buildErrorResponse: (state) => OidcErrorResponse.fromJson({
              'error': 'access_denied',
              'state': ?state,
            }),
          );

          await expectLater(
            manager.loginAuthorizationCodeFlow(),
            throwsA(
              predicate(
                (e) => e is OidcException && e.toString().contains('mix-up'),
              ),
            ),
          );
        },
      );

      test(
        'present-but-mismatched iss on an error response is rejected as a '
        'mix-up',
        () async {
          final manager = await _buildManager(
            issSupported: true,
            buildErrorResponse: (state) => OidcErrorResponse.fromJson({
              'error': 'access_denied',
              'iss': 'https://attacker.example',
              'state': ?state,
            }),
          );

          await expectLater(
            manager.loginAuthorizationCodeFlow(),
            throwsA(
              predicate(
                (e) => e is OidcException && e.toString().contains('mix-up'),
              ),
            ),
          );
        },
      );

      test(
        'matching iss on an error response lets the original server error '
        'through unchanged',
        () async {
          final manager = await _buildManager(
            issSupported: true,
            buildErrorResponse: (state) => OidcErrorResponse.fromJson({
              'error': 'access_denied',
              'iss': _issuer.toString(),
              'state': ?state,
            }),
          );

          await expectLater(
            manager.loginAuthorizationCodeFlow(),
            throwsA(
              predicate(
                (e) =>
                    e is OidcException &&
                    !e.toString().contains('mix-up') &&
                    e.errorResponse?.error == 'access_denied',
              ),
            ),
          );
        },
      );

      test(
        'lenient: when the AS does not advertise iss support, a missing iss '
        'on an error response is not treated as a mix-up',
        () async {
          final manager = await _buildManager(
            issSupported: false,
            buildErrorResponse: (state) => OidcErrorResponse.fromJson({
              'error': 'access_denied',
              'state': ?state,
            }),
          );

          await expectLater(
            manager.loginAuthorizationCodeFlow(),
            throwsA(
              predicate(
                (e) =>
                    e is OidcException &&
                    !e.toString().contains('mix-up') &&
                    e.errorResponse?.error == 'access_denied',
              ),
            ),
          );
        },
      );
    },
  );
}
