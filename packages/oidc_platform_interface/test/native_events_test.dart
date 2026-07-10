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

  test('OidcNativeError.toString formats all fields', () {
    const error = OidcNativeError(
      kind: OidcNativeErrorKind.noBrowserAvailable,
      nativeDomain: 'com.example.domain',
      nativeCode: 7,
      message: 'no browser',
    );
    expect(
      error.toString(),
      'OidcNativeError(noBrowserAvailable, domain: com.example.domain, '
      'code: 7, message: no browser)',
    );
  });

  test('OidcNativeError.fromMap defaults raw to an empty map when absent', () {
    final error = OidcNativeError.fromMap(const {'kind': 'startFailed'});
    expect(error.kind, OidcNativeErrorKind.startFailed);
    expect(error.raw, isEmpty);
    expect(error.nativeDomain, isNull);
    expect(error.nativeCode, isNull);
  });

  group('error kind parsing covers every native failure bucket', () {
    for (final entry in {
      'userCancelled': OidcNativeErrorKind.userCancelled,
      'presentationContextNotProvided':
          OidcNativeErrorKind.presentationContextNotProvided,
      'presentationContextInvalid':
          OidcNativeErrorKind.presentationContextInvalid,
      'startFailed': OidcNativeErrorKind.startFailed,
      'verificationFailed': OidcNativeErrorKind.verificationFailed,
      'verificationTimedOut': OidcNativeErrorKind.verificationTimedOut,
      'noBrowserAvailable': OidcNativeErrorKind.noBrowserAvailable,
      'somethingUnmodeled': OidcNativeErrorKind.platformError,
    }.entries) {
      test('${entry.key} -> ${entry.value.name}', () {
        final e = OidcNativeBrowserEvent.fromMap({
          'type': 'failed',
          'error': {'kind': entry.key},
        })! as OidcBrowserFlowFailedEvent;
        expect(e.error.kind, entry.value);
      });
    }
  });

  test('fromMap without a timestamp falls back to DateTime.now()', () {
    final before = DateTime.now();
    final e = OidcNativeBrowserEvent.fromMap(const {'type': 'cancelled'})!;
    final after = DateTime.now();
    expect(
      e.at.isAfter(before.subtract(const Duration(seconds: 1))) &&
          e.at.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('opened event defaults session type and capture mode to unknown', () {
    final e = OidcNativeBrowserEvent.fromMap(const {'type': 'opened'})!
        as OidcBrowserOpenedEvent;
    expect(e.sessionType, OidcNativeSessionType.unknown);
    expect(e.captureMode, OidcRedirectCaptureMode.unknown);
    expect(e.resolvedBrowserPackage, isNull);
  });
}
