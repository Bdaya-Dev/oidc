import 'package:oidc_core/src/_exports.dart';
import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';
import 'package:test/test.dart';

// Mock hooks for testing different combinations
class MockRequestModifierHook
    with
        OidcHookMixin<String, String>,
        OidcRequestModifierHookMixin<String, String> {
  @override
  Future<String> modifyRequest(String request) async {
    return '$request-req-modified';
  }
}

class MockResponseModifierHook
    with
        OidcHookMixin<String, String>,
        OidcResponseModifierHookMixin<String, String> {
  @override
  Future<String> modifyResponse(String response) async {
    return '$response-resp-modified';
  }
}

class MockExecutionHook
    with OidcHookMixin<String, String>, OidcExecutionHookMixin<String, String> {
  @override
  Future<String> modifyExecution(
    String request,
    OidcHookExecution<String, String> defaultExecution,
  ) async {
    final result = await defaultExecution('$request-exec-modified');
    return '$result-exec-postfix';
  }
}

class MockFullHook
    with
        OidcHookMixin<String, String>,
        OidcRequestModifierHookMixin<String, String>,
        OidcResponseModifierHookMixin<String, String>,
        OidcExecutionHookMixin<String, String> {
  @override
  Future<String> modifyRequest(String request) async {
    return '$request-full-req';
  }

  @override
  Future<String> modifyResponse(String response) async {
    return '$response-full-resp';
  }

  @override
  Future<String> modifyExecution(
    String request,
    OidcHookExecution<String, String> defaultExecution,
  ) async {
    final result = await defaultExecution('$request-full-exec');
    return '$result-full-exec-post';
  }
}

void main() {
  group('oidcExecuteHook', () {
    test('executes default execution when hook is null', () async {
      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default-executed',
        hook: null,
      );

      expect(result, equals('test-request-default-executed'));
    });

    test('applies request modifier hook only', () async {
      final hook = MockRequestModifierHook();
      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default',
        hook: hook,
      );

      expect(result, equals('test-request-req-modified-default'));
    });

    test('applies response modifier hook only', () async {
      final hook = MockResponseModifierHook();
      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default',
        hook: hook,
      );

      expect(result, equals('test-request-default-resp-modified'));
    });

    test('applies execution hook only', () async {
      final hook = MockExecutionHook();
      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default',
        hook: hook,
      );

      expect(result, equals('test-request-exec-modified-default-exec-postfix'));
    });

    test('applies all hook types in correct order', () async {
      final hook = MockFullHook();
      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default',
        hook: hook,
      );

      // Order: modifyRequest -> modifyExecution (with modified request) -> modifyResponse
      expect(
        result,
        equals(
          'test-request-full-req-full-exec-default-full-exec-post-full-resp',
        ),
      );
    });

    test(
      'handles combination of request and response modifier hooks',
      () async {
        final hook = OidcHook<String, String>(
          modifyRequest: (request) async => '$request-custom-req',
          modifyResponse: (response) async => '$response-custom-resp',
        );

        final result = await oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-default',
          hook: hook,
        );

        expect(result, equals('test-request-custom-req-default-custom-resp'));
      },
    );

    test(
      'handles combination of request modifier and execution hooks',
      () async {
        final hook = OidcHook<String, String>(
          modifyRequest: (request) async => '$request-custom-req',
          modifyExecution: (request, defaultExecution) async {
            final result = await defaultExecution('$request-custom-exec');
            return '$result-exec-done';
          },
        );

        final result = await oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-default',
          hook: hook,
        );

        expect(
          result,
          equals('test-request-custom-req-custom-exec-default-exec-done'),
        );
      },
    );

    test(
      'handles combination of response modifier and execution hooks',
      () async {
        final hook = OidcHook<String, String>(
          modifyResponse: (response) async => '$response-custom-resp',
          modifyExecution: (request, defaultExecution) async {
            final result = await defaultExecution('$request-custom-exec');
            return '$result-exec-done';
          },
        );

        final result = await oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-default',
          hook: hook,
        );

        expect(
          result,
          equals('test-request-custom-exec-default-exec-done-custom-resp'),
        );
      },
    );

    test('handles empty hook with all mixins but no implementations', () async {
      // Create a hook that has the mixins but doesn't override methods
      final hook = OidcHook<String, String>();

      final result = await oidcExecuteHook<String, String>(
        request: 'test-request',
        defaultExecution: (request) async => '$request-default',
        hook: hook,
      );

      expect(result, equals('test-request-default'));
    });
  });

  group('OidcHookExtensions.execute', () {
    test('executes with null hook', () async {
      const OidcHookMixin<String, String>? nullHook = null;

      final result = await nullHook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      expect(result, equals('test-request-executed'));
    });

    test('executes with non-null hook', () async {
      final hook = MockRequestModifierHook() as OidcHookMixin<String, String>?;

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      expect(result, equals('test-request-req-modified-executed'));
    });

    test('executes with complex hook combination', () async {
      final hook = MockFullHook() as OidcHookMixin<String, String>?;

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      expect(
        result,
        equals(
          'test-request-full-req-full-exec-executed-full-exec-post-full-resp',
        ),
      );
    });

    test('executes with OidcHook instance', () async {
      final hook =
          OidcHook<String, String>(
                modifyRequest: (request) async => '$request-oidc-req',
                modifyResponse: (response) async => '$response-oidc-resp',
                modifyExecution: (request, defaultExecution) async {
                  final result = await defaultExecution('$request-oidc-exec');
                  return '$result-oidc-exec-done';
                },
              )
              as OidcHookMixin<String, String>?;

      final result = await hook.execute(
        request: 'test-request',
        defaultExecution: (request) async => '$request-executed',
      );

      expect(
        result,
        equals(
          'test-request-oidc-req-oidc-exec-executed-oidc-exec-done-oidc-resp',
        ),
      );
    });

    test('preserves execution order across multiple calls', () async {
      final hook =
          OidcHook<String, String>(
                modifyRequest: (request) async => '$request-modified',
                modifyResponse: (response) async => '$response-modified',
              )
              as OidcHookMixin<String, String>?;

      // Execute multiple times to ensure consistency
      for (var i = 0; i < 3; i++) {
        final result = await hook.execute(
          request: 'test-$i',
          defaultExecution: (request) async => '$request-executed',
        );

        expect(result, equals('test-$i-modified-executed-modified'));
      }
    });
  });

  group('Edge cases and error handling', () {
    test('handles async exceptions in request modifier', () async {
      final hook = OidcHook<String, String>(
        modifyRequest: (request) async {
          throw Exception('Request modifier error');
        },
      );

      expect(
        () => oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
          hook: hook,
        ),
        throwsException,
      );
    });

    test('handles async exceptions in response modifier', () async {
      final hook = OidcHook<String, String>(
        modifyResponse: (response) async {
          throw Exception('Response modifier error');
        },
      );

      expect(
        () => oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
          hook: hook,
        ),
        throwsException,
      );
    });

    test('handles async exceptions in execution modifier', () async {
      final hook = OidcHook<String, String>(
        modifyExecution: (request, defaultExecution) async {
          throw Exception('Execution modifier error');
        },
      );

      expect(
        () => oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async => '$request-executed',
          hook: hook,
        ),
        throwsException,
      );
    });

    test('handles async exceptions in default execution', () async {
      final hook = MockRequestModifierHook();

      expect(
        () => oidcExecuteHook<String, String>(
          request: 'test-request',
          defaultExecution: (request) async {
            throw Exception('Default execution error');
          },
          hook: hook,
        ),
        throwsException,
      );
    });
  });
}
