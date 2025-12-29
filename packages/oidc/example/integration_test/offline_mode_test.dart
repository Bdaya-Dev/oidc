import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oidc/oidc.dart';
import 'package:oidc_example/main.dart' as example;

const _issuer = 'https://test.example.com';
const _audience = 'test-client';
const _testSubject = 'user-123';

var _appStarted = false;

Future<void> _ensureAppStarted(WidgetTester tester) async {
  if (!_appStarted) {
    example.main();
    _appStarted = true;
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline mode integration', () {
    testWidgets('enters offline mode after refresh failure', (tester) async {
      await _ensureAppStarted(tester);

      final tokenQueue = Queue<dynamic>()
        ..add(const SocketException('Network unreachable'));
      final manager = createManager(tokenQueue: tokenQueue);
      await manager.init();

      final initialToken = _buildToken('initial');
      final user = await manager.seedUserWithToken(initialToken);

      final events = <OidcEvent>[];
      final eventsSub = manager.events().listen(events.add);

      final refreshResult = await manager.refreshToken();
      await tester.pump();

      expect(refreshResult, same(user));
      expect(refreshResult?.token.accessToken, 'access-initial');
      expect(manager.isInOfflineMode, isTrue);
      expect(
        events.whereType<OidcOfflineModeEnteredEvent>().length,
        greaterThanOrEqualTo(1),
      );
      expect(events.whereType<OidcOfflineAuthWarningEvent>(), isEmpty);

      await eventsSub.cancel();
      await manager.dispose();
    });

    testWidgets('exits offline mode after subsequent success', (tester) async {
      await _ensureAppStarted(tester);

      final tokenQueue = Queue<dynamic>()
        ..add(const SocketException('Temporary failure'))
        ..add(_buildTokenResponse('refreshed'));
      final manager = createManager(tokenQueue: tokenQueue);
      await manager.init();

      final initialToken = _buildToken('initial');
      await manager.seedUserWithToken(initialToken);

      final events = <OidcEvent>[];
      final eventsSub = manager.events().listen(events.add);

      final firstAttempt = await manager.refreshToken();
      await tester.pump();
      expect(firstAttempt, isNotNull);
      expect(firstAttempt?.token.accessToken, 'access-initial');
      expect(manager.isInOfflineMode, isTrue);

      final secondAttempt = await manager.refreshToken();
      await tester.pump();
      expect(secondAttempt, isNotNull);
      expect(secondAttempt?.token.accessToken, 'access-refreshed');
      expect(manager.isInOfflineMode, isFalse);

      expect(events.whereType<OidcOfflineModeEnteredEvent>().length, 1);
      expect(events.whereType<OidcOfflineModeExitedEvent>().length, 1);
      expect(manager.visibleConsecutiveRefreshFailures, 0);

      await eventsSub.cancel();
      await manager.dispose();
    });

    testWidgets('emits warning after repeated refresh failures', (
      tester,
    ) async {
      await _ensureAppStarted(tester);

      final tokenQueue = Queue<dynamic>()
        ..add(const SocketException('failure-1'))
        ..add(const SocketException('failure-2'));
      final manager = createManager(
        tokenQueue: tokenQueue,
        warningThreshold: 2,
      );
      await manager.init();

      final initialToken = _buildToken('initial');
      await manager.seedUserWithToken(initialToken);

      final events = <OidcEvent>[];
      final eventsSub = manager.events().listen(events.add);

      await manager.refreshToken();
      await tester.pump();
      expect(events.whereType<OidcOfflineAuthWarningEvent>(), isEmpty);

      await manager.refreshToken();
      await tester.pump();
      final warnings = events.whereType<OidcOfflineAuthWarningEvent>().toList();
      expect(
        warnings
            .where(
              (event) =>
                  event.warningType ==
                  OfflineAuthWarningType.repeatRefreshFailure,
            )
            .length,
        greaterThanOrEqualTo(1),
      );

      await eventsSub.cancel();
      await manager.dispose();
    });
  });
}

OfflineTestUserManager createManager({
  required Queue<dynamic> tokenQueue,
  int warningThreshold = 3,
}) {
  final metadata = OidcProviderMetadata.fromJson({
    'issuer': _issuer,
    'authorization_endpoint': '$_issuer/authorize',
    'token_endpoint': '$_issuer/token',
    'jwks_uri': '$_issuer/jwks',
    'response_types_supported': ['code'],
    'subject_types_supported': ['public'],
    'id_token_signing_alg_values_supported': ['none'],
    'token_endpoint_auth_methods_supported': ['none'],
    'grant_types_supported': ['authorization_code', 'refresh_token'],
  });

  final settings = OidcUserManagerSettings(
    redirectUri: Uri.parse('com.example.test:/callback'),
    scope: const ['openid', 'offline_access'],
    supportOfflineAuth: true,
    offlineRepeatFailureWarningThreshold: warningThreshold,
    userInfoSettings: const OidcUserInfoSettings(sendUserInfoRequest: false),
    refreshBefore: (_) => null,
    hooks: OidcUserManagerHooks(
      token: OidcHook<OidcTokenHookRequest, OidcTokenResponse>(
        modifyExecution: (request, defaultExecution) async {
          if (tokenQueue.isEmpty) {
            return defaultExecution(request);
          }
          final entry = tokenQueue.removeFirst();
          if (entry is OidcTokenResponse) {
            return entry;
          }
          if (entry is Future<OidcTokenResponse>) {
            return entry;
          }
          if (entry is OidcTokenResponse Function(OidcTokenHookRequest)) {
            return entry(request);
          }
          if (entry is Exception) {
            throw entry;
          }
          if (entry is Error) {
            throw entry;
          }
          throw StateError(
            'Unsupported token hook entry: ${entry.runtimeType}',
          );
        },
      ),
    ),
  );

  return OfflineTestUserManager(
    discoveryDocument: metadata,
    clientCredentials: const OidcClientAuthentication.none(clientId: _audience),
    store: OidcMemoryStore(),
    settings: settings,
  );
}

OidcToken _buildToken(String label) {
  final response = _buildTokenResponse(label);
  return OidcToken.fromResponse(response, sessionState: 'session-$label');
}

OidcTokenResponse _buildTokenResponse(String label) {
  final idToken = _createUnsignedIdToken(validity: const Duration(minutes: 10));
  return OidcTokenResponse.fromJson({
    'access_token': 'access-$label',
    'refresh_token': 'refresh-$label',
    'token_type': 'Bearer',
    'expires_in': 600,
    'id_token': idToken,
  });
}

String _createUnsignedIdToken({
  Duration validity = const Duration(minutes: 5),
}) {
  final header = base64UrlEncode(
    utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})),
  ).replaceAll('=', '');
  final now = clock.now();
  final payload = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'iss': _issuer,
        'sub': _testSubject,
        'aud': _audience,
        'exp': (now.add(validity).millisecondsSinceEpoch ~/ 1000),
        'iat': (now.millisecondsSinceEpoch ~/ 1000),
      }),
    ),
  ).replaceAll('=', '');
  return '$header.$payload.';
}

class OfflineTestUserManager extends OidcUserManager {
  OfflineTestUserManager({
    required super.discoveryDocument,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    super.id,
  });

  OfflineTestUserManager.lazy({
    required super.discoveryDocumentUri,
    required super.clientCredentials,
    required super.store,
    required super.settings,
    super.httpClient,
    super.keyStore,
    super.id,
  }) : super.lazy();

  int get visibleConsecutiveRefreshFailures => consecutiveRefreshFailures;

  Future<OidcUser> seedUserWithToken(OidcToken token) async {
    final user = await createUserFromToken(
      token: token,
      nonce: null,
      attributes: null,
      userInfo: null,
      metadata: currentDiscoveryDocument!,
    );
    if (user == null) {
      throw StateError('Failed to seed user for tests');
    }
    return user;
  }
}
