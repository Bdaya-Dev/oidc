// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/src/logger.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_desktop/oidc_desktop.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

class MockDesktopImpl extends OidcPlatform with OidcDesktop {
  MockDesktopImpl({
    this.successfulPageResponse,
    this.methodMismatchResponse,
    this.notFoundResponse,
  });

  final String? successfulPageResponse;
  final String? methodMismatchResponse;
  final String? notFoundResponse;

  @override
  OidcPlatformSpecificOptions_Native getNativeOptions(
    OidcPlatformSpecificOptions options,
  ) {
    return OidcPlatformSpecificOptions_Native(
      successfulPageResponse: successfulPageResponse,
      methodMismatchResponse: methodMismatchResponse,
      notFoundResponse: notFoundResponse,
    );
  }

  @override
  Logger get logger => Logger('Oidc.Mock');
}

final successfulPageResponseValues = [null, 'a'];
final methodMismatchResponseValues = [null, 'b'];
final notFoundResponseValues = [null, 'c'];
void main() {
  group('OidcDesktop', () {
    for (final successfulPageResponse in successfulPageResponseValues) {
      group('(successfulPageResponse: $successfulPageResponse)', () {
        for (final methodMismatchResponse in methodMismatchResponseValues) {
          group('(methodMismatchResponse: $methodMismatchResponse)', () {
            for (final notFoundResponse in notFoundResponseValues) {
              group('(notFoundResponse: $notFoundResponse)', () {
                final oidc = MockDesktopImpl(
                  methodMismatchResponse: methodMismatchResponse,
                  notFoundResponse: notFoundResponse,
                  successfulPageResponse: successfulPageResponse,
                );
                test('can be instantiated', () {
                  expect(oidc, isNotNull);
                });
                test('getAuthorizationResponse', () {
                  // oidc.getAuthorizationResponse(
                  //   metadata,
                  //   request,
                  //   options,
                  // );
                });
              });
            }
          });
        }
      });
    }
  });
}
