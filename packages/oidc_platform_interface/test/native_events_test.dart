import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';

void main() {
  test('native events are OidcEvents (flow through manager.events())', () {
    final e = OidcNativeBrowserEvent.fromMap(const {
      'type': 'opening',
      'flowId': '1',
      'timestampMs': 1000,
    });
    expect(e, isA<OidcBrowserOpeningEvent>());
    expect(e, isA<OidcEvent>());
    expect(e!.flowId, '1');
    expect(e.at, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('parses opened event with session type + capture mode', () {
    final e = OidcNativeBrowserEvent.fromMap(const {
      'type': 'opened',
      'sessionType': 'ephemeral',
      'captureMode': 'asWebAuthenticationSession',
    })! as OidcBrowserOpenedEvent;
    expect(e.sessionType, OidcNativeSessionType.ephemeral);
    expect(e.captureMode, OidcRedirectCaptureMode.asWebAuthenticationSession);
  });

  test('parses redacted redirectReceived (no raw URI)', () {
    final e = OidcNativeBrowserEvent.fromMap(const {
      'type': 'redirectReceived',
      'scheme': 'com.example.app',
      'host': 'cb',
      'hasCode': true,
      'hasState': true,
      'hasError': false,
    })! as OidcBrowserRedirectReceivedEvent;
    expect(e.scheme, 'com.example.app');
    expect(e.host, 'cb');
    expect(e.hasCode, true);
    expect(e.hasState, true);
    expect(e.hasError, false);
  });

  test('parses failed with structured native error', () {
    final e = OidcNativeBrowserEvent.fromMap(const {
      'type': 'failed',
      'error': {
        'kind': 'presentationContextInvalid',
        'nativeDomain': 'ASWebAuthenticationSessionErrorDomain',
        'nativeCode': -3,
        'message': 'closed',
      },
    })! as OidcBrowserFlowFailedEvent;
    expect(e.error.kind, OidcNativeErrorKind.presentationContextInvalid);
    expect(e.error.nativeDomain, 'ASWebAuthenticationSessionErrorDomain');
    expect(e.error.nativeCode, -3);
  });

  test('parses cancelled + warning', () {
    expect(
      OidcNativeBrowserEvent.fromMap(const {'type': 'cancelled'}),
      isA<OidcBrowserFlowCancelledEvent>(),
    );
    final w = OidcNativeBrowserEvent.fromMap(const {
      'type': 'warning',
      'code': 'EPHEMERAL_UNSUPPORTED',
    })! as OidcBrowserNativeWarningEvent;
    expect(w.code, 'EPHEMERAL_UNSUPPORTED');
  });

  test('returns null for an unknown event type (forward-compatible)', () {
    expect(OidcNativeBrowserEvent.fromMap(const {'type': 'mystery'}), isNull);
  });
}
