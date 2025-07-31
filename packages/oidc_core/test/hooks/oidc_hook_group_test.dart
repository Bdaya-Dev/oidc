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

  @override
  Future<String> execute({
    required String request,
    required OidcHookExecution<String, String> defaultExecution,
  }) async {
    final modifiedRequest = await modifyRequest(request);
    return defaultExecution(modifiedRequest);
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

  @override
  Future<String> execute({
    required String request,
    required OidcHookExecution<String, String> defaultExecution,
  }) async {
    final response = await defaultExecution(request);
    return modifyResponse(response);
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

    group('execute method', () {
      test('execute applies request and response hooks in correct order',
          () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [
            MockRequestModifierHook(),
            MockResponseModifierHook(),
          ],
        );

        final result = await hookGroup.execute(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
        );

        // Should apply: request modification -> execution -> response modification
        expect(result, equals('test-request-modified-executed-modified'));
      });

      test('execute with executionHook controls entire flow', () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [
            MockRequestModifierHook(),
            MockResponseModifierHook(),
          ],
          executionHook: OidcHook(
            modifyExecution: (request, defaultExecution) async {
              return '${await defaultExecution('$request-custom')}-custom-execution';
            },
          ),
        );

        final result = await hookGroup.execute(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
        );

        // Should apply: request modification -> custom execution -> response modification
        expect(
            result,
            equals(
                'test-request-modified-custom-executed-custom-execution-modified'));
      });

      test('execute with multiple request hooks applies them in sequence',
          () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [
            MockRequestModifierHook(), // adds '-modified'
            MockRequestModifierHook(), // adds another '-modified'
          ],
        );

        final result = await hookGroup.execute(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
        );

        expect(result, equals('test-request-modified-modified-executed'));
      });

      test('execute with multiple response hooks applies them in sequence',
          () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [
            MockResponseModifierHook(), // adds '-modified'
            MockResponseModifierHook(), // adds another '-modified'
          ],
        );

        final result = await hookGroup.execute(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
        );

        expect(result, equals('test-request-executed-modified-modified'));
      });

      test('execute with empty hooks just runs default execution', () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [],
        );

        final result = await hookGroup.execute(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
        );

        expect(result, equals('test-request-executed'));
      });

      test('execute orchestrates complete hook lifecycle', () async {
        final hookGroup = OidcHookGroup<String, String>(
          hooks: [
            MockRequestModifierHook(),
            MockResponseModifierHook(),
          ],
          executionHook: OidcHook(
            modifyExecution: (request, defaultExecution) async {
              final response =
                  await defaultExecution('$request-execution-modified');
              return '$response-execution-processed';
            },
          ),
        );

        final result = await hookGroup.execute(
          request: 'original-request',
          defaultExecution: (request) async => '$request-default-executed',
        );

        // Flow: request hook -> execution hook -> default execution -> execution hook -> response hook
        expect(
            result,
            equals(
                'original-request-modified-execution-modified-default-executed-execution-processed-modified'));
      });
    });
  });
}
