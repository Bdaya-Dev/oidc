import 'package:oidc_core/src/_exports.dart';
import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';
import 'package:test/test.dart';

class MockRequestModifierHook
    with
        OidcHookMixin<String, String>,
        OidcRequestModifierHookMixin<String, String> {
  @override
  Future<String> modifyRequest(String request) async {
    return '$request-modified';
  }
}

class MockResponseModifierHook
    with
        OidcHookMixin<String, String>,
        OidcResponseModifierHookMixin<String, String> {
  @override
  Future<String> modifyResponse(String response) async {
    return '$response-modified';
  }
}

void main() {
  group('OidcHookGroup', () {
    test('modifyRequest applies all hooks in sequence', () async {
      final hookGroup = OidcHookGroup<String, String>(
        hooks: [MockRequestModifierHook(), MockRequestModifierHook()],
      );

      final result = await hookGroup.modifyRequest('test-request');
      expect(result, equals('test-request-modified-modified'));
    });

    test('modifyResponse applies all hooks in sequence', () async {
      final hookGroup = OidcHookGroup<String, String>(
        hooks: [MockResponseModifierHook(), MockResponseModifierHook()],
      );

      final result = await hookGroup.modifyResponse('test-response');
      expect(result, equals('test-response-modified-modified'));
    });

    test('modifyRequest and modifyResponse work together', () async {
      final hookGroup = OidcHookGroup<String, String>(
        hooks: [
          MockRequestModifierHook(),
          MockResponseModifierHook(),
        ],
      );

      final requestResult = await hookGroup.modifyRequest('test-request');
      expect(requestResult, equals('test-request-modified'));

      final responseResult = await hookGroup.modifyResponse('test-response');
      expect(responseResult, equals('test-response-modified'));
    });

    test('executionHook is called if provided', () async {
      final executionHook = OidcHookGroup<String, String>(
        hooks: [],
        executionHook: OidcHook(
          modifyExecution: (response, defaultExecution) async {
            return '${await defaultExecution('$response-default')}-modifyexecuted';
          },
        ),
      );

      final result = await executionHook.modifyExecution(
        'test-request',
        (request) async => '$request-executed',
      );

      expect(result, equals('test-request-default-executed-modifyexecuted'));
    });
  });
}
