import 'package:oidc_core/src/hooks/oidc_hook_mixin.dart';
import 'package:test/test.dart';
import 'package:oidc_core/src/hooks/oidc_hook_group.dart';
import 'package:oidc_core/src/hooks/oidc_request_response_hook_mixin.dart';

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
  });
}
