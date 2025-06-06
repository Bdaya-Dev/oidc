import 'package:test/test.dart';
import 'package:oidc_core/src/hooks/oidc_request_hook.dart';

void main() {
  group('OidcRequestHook', () {
    test('modifyRequest modifies the request as expected', () async {
      final hook = OidcRequestHook<String, String>(
        modifyRequest: (request) async => '$request-modified',
      );

      final result = await hook.modifyRequest('test-request');
      expect(result, equals('test-request-modified'));
    });

    test('modifyResponse modifies the response as expected', () async {
      final hook = OidcRequestHook<String, String>(
        modifyResponse: (response) async => '$response-modified',
      );

      final result = await hook.modifyResponse('test-response');
      expect(result, equals('test-response-modified'));
    });

    test('modifyExecution modifies the execution as expected', () async {
      final hook = OidcRequestHook<String, String>(
        modifyExecution: (request, defaultExecution) async {
          final defaultResult = await defaultExecution('$request-default');
          return '$defaultResult-modified';
        },
      );

      final result = await hook.modifyExecution(
        'test-request',
        (request) async => '$request-executed',
      );

      expect(result, equals('test-request-default-executed-modified'));
    });
  });
}
