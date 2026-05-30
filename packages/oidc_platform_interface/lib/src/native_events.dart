// ignore_for_file: sort_constructors_first

/// Typed, observable events emitted by the first-party native browser layer
/// (`oidc_android` Custom Tabs / `oidc_ios`+`oidc_macos`
/// `ASWebAuthenticationSession`).
///
/// These are [OidcEvent]s, so consumers observe them through the **existing**
/// `OidcUserManager.events()` stream alongside token/offline/logout events —
/// there is no separate observability API. They give visibility into the
/// native flow (which browser/session was used, when the redirect arrived,
/// granular failures) without leaking platform internals or secrets.
library;

import 'package:oidc_core/oidc_core.dart';

/// Whether the native session was a standard or ephemeral (incognito) one.
enum OidcNativeSessionType {
  /// Shares cookies/cache with the user's browser session.
  standard,

  /// Ephemeral / incognito (no shared cookies/cache).
  ephemeral,

  /// Unknown / not reported.
  unknown,
}

/// How the redirect was captured.
enum OidcRedirectCaptureMode {
  /// Android Auth Tab (browser returns the redirect via an ActivityResult).
  authTab,

  /// Android Custom Tabs + the plugin-owned `OidcRedirectActivity`.
  customTabsRedirectActivity,

  /// iOS/macOS `ASWebAuthenticationSession` completion handler.
  asWebAuthenticationSession,

  /// Unknown / not reported.
  unknown,
}

/// Typed bucket for a native failure.
enum OidcNativeErrorKind {
  /// The user dismissed the browser.
  userCancelled,

  /// iOS/macOS: no presentation context was provided.
  presentationContextNotProvided,

  /// iOS/macOS: the presentation context was invalid/closed.
  presentationContextInvalid,

  /// The session failed to start (`canStart`/`start()` returned false).
  startFailed,

  /// Android Auth Tab: https App-Links verification failed.
  verificationFailed,

  /// Android Auth Tab: https App-Links verification timed out.
  verificationTimedOut,

  /// Android: no Custom Tabs / browser provider available.
  noBrowserAvailable,

  /// Anything else — consult [OidcNativeError.nativeDomain]/`nativeCode`/`raw`.
  platformError,
}

/// A structured native error preserving the original platform detail.
class OidcNativeError {
  ///
  const OidcNativeError({
    required this.kind,
    this.nativeDomain,
    this.nativeCode,
    this.message,
    this.raw = const {},
  });

  /// Typed classification.
  final OidcNativeErrorKind kind;

  /// e.g. `ASWebAuthenticationSessionErrorDomain` (iOS/macOS).
  final String? nativeDomain;

  /// Raw `NSError.code` / Android `AuthResult` result code.
  final int? nativeCode;

  /// Human-readable message.
  final String? message;

  /// Escape hatch for unmodeled detail.
  final Map<String, Object?> raw;

  /// Parses a native error map.
  factory OidcNativeError.fromMap(Map<Object?, Object?> map) {
    return OidcNativeError(
      kind: _errorKind(map['kind'] as String?),
      nativeDomain: map['nativeDomain'] as String?,
      nativeCode: (map['nativeCode'] as num?)?.toInt(),
      message: map['message'] as String?,
      raw: (map['raw'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  @override
  String toString() => 'OidcNativeError(${kind.name}, domain: $nativeDomain, '
      'code: $nativeCode, message: $message)';
}

/// Base type for native browser-layer events. An [OidcEvent], so it flows
/// through `OidcUserManager.events()`. Sealed so a Dart `switch` is exhaustive.
sealed class OidcNativeBrowserEvent extends OidcEvent {
  ///
  const OidcNativeBrowserEvent({
    required super.at,
    this.flowId,
    super.additionalInfo,
  });

  /// Correlates events belonging to one authorize/endSession invocation.
  final String? flowId;

  /// Parses a native event map into a typed event. Returns null for an
  /// unrecognized event type (forward-compatibility).
  static OidcNativeBrowserEvent? fromMap(Map<Object?, Object?> map) {
    final flowId = map['flowId'] as String?;
    final ts = (map['timestampMs'] as num?)?.toInt();
    final at =
        ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime.now();
    switch (map['type'] as String?) {
      case 'opening':
        return OidcBrowserOpeningEvent(at: at, flowId: flowId);
      case 'opened':
        return OidcBrowserOpenedEvent(
          at: at,
          flowId: flowId,
          resolvedBrowserPackage: map['resolvedBrowserPackage'] as String?,
          sessionType: _sessionType(map['sessionType'] as String?),
          captureMode: _captureMode(map['captureMode'] as String?),
        );
      case 'redirectReceived':
        return OidcBrowserRedirectReceivedEvent(
          at: at,
          flowId: flowId,
          scheme: map['scheme'] as String?,
          host: map['host'] as String?,
          hasCode: map['hasCode'] as bool? ?? false,
          hasState: map['hasState'] as bool? ?? false,
          hasError: map['hasError'] as bool? ?? false,
        );
      case 'cancelled':
        return OidcBrowserFlowCancelledEvent(at: at, flowId: flowId);
      case 'failed':
        return OidcBrowserFlowFailedEvent(
          at: at,
          flowId: flowId,
          error: OidcNativeError.fromMap(
            (map['error'] as Map?)?.cast<Object?, Object?>() ?? const {},
          ),
        );
      case 'warning':
        return OidcBrowserNativeWarningEvent(
          at: at,
          flowId: flowId,
          code: map['code'] as String? ?? 'UNKNOWN',
        );
      default:
        return null;
    }
  }
}

/// The native browser is about to be presented.
final class OidcBrowserOpeningEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserOpeningEvent({required super.at, super.flowId});
}

/// The native browser was presented.
final class OidcBrowserOpenedEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserOpenedEvent({
    required super.at,
    super.flowId,
    this.resolvedBrowserPackage,
    this.sessionType = OidcNativeSessionType.unknown,
    this.captureMode = OidcRedirectCaptureMode.unknown,
  });

  /// Android: the resolved Custom Tabs provider package (null = none / default
  /// `ACTION_VIEW`). Not applicable on iOS/macOS.
  final String? resolvedBrowserPackage;

  /// Whether a standard or ephemeral session was used.
  final OidcNativeSessionType sessionType;

  /// How the redirect will be captured.
  final OidcRedirectCaptureMode captureMode;
}

/// A redirect was received and matched. Deliberately **redacted** — it carries
/// no raw URI (to avoid leaking `code`/`state`/tokens to logs) but exposes
/// enough to debug a redirect-match failure.
final class OidcBrowserRedirectReceivedEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserRedirectReceivedEvent({
    required super.at,
    super.flowId,
    this.scheme,
    this.host,
    this.hasCode = false,
    this.hasState = false,
    this.hasError = false,
  });

  /// Redirect scheme (e.g. `com.example.app`).
  final String? scheme;

  /// Redirect host, if present.
  final String? host;

  /// Whether a `code` parameter was present.
  final bool hasCode;

  /// Whether a `state` parameter was present.
  final bool hasState;

  /// Whether an `error` parameter was present.
  final bool hasError;
}

/// The user dismissed the browser (typed + catchable).
final class OidcBrowserFlowCancelledEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserFlowCancelledEvent({required super.at, super.flowId});
}

/// The native flow failed with a structured error.
final class OidcBrowserFlowFailedEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserFlowFailedEvent({
    required this.error,
    required super.at,
    super.flowId,
  });

  /// The structured native error.
  final OidcNativeError error;
}

/// A non-fatal native warning (e.g. an unsupported option was ignored).
final class OidcBrowserNativeWarningEvent extends OidcNativeBrowserEvent {
  ///
  const OidcBrowserNativeWarningEvent({
    required this.code,
    required super.at,
    super.flowId,
  });

  /// A stable warning code, e.g. `ADDITIONAL_HEADERS_UNSUPPORTED`,
  /// `EPHEMERAL_UNSUPPORTED`.
  final String code;
}

OidcNativeSessionType _sessionType(String? v) => switch (v) {
      'standard' => OidcNativeSessionType.standard,
      'ephemeral' => OidcNativeSessionType.ephemeral,
      _ => OidcNativeSessionType.unknown,
    };

OidcRedirectCaptureMode _captureMode(String? v) => switch (v) {
      'authTab' => OidcRedirectCaptureMode.authTab,
      'customTabsRedirectActivity' =>
        OidcRedirectCaptureMode.customTabsRedirectActivity,
      'asWebAuthenticationSession' =>
        OidcRedirectCaptureMode.asWebAuthenticationSession,
      _ => OidcRedirectCaptureMode.unknown,
    };

OidcNativeErrorKind _errorKind(String? v) => switch (v) {
      'userCancelled' => OidcNativeErrorKind.userCancelled,
      'presentationContextNotProvided' =>
        OidcNativeErrorKind.presentationContextNotProvided,
      'presentationContextInvalid' =>
        OidcNativeErrorKind.presentationContextInvalid,
      'startFailed' => OidcNativeErrorKind.startFailed,
      'verificationFailed' => OidcNativeErrorKind.verificationFailed,
      'verificationTimedOut' => OidcNativeErrorKind.verificationTimedOut,
      'noBrowserAvailable' => OidcNativeErrorKind.noBrowserAvailable,
      _ => OidcNativeErrorKind.platformError,
    };
