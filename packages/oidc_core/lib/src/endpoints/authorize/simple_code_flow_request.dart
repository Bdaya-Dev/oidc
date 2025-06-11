import 'package:oidc_core/oidc_core.dart';

/// This authorization request takes only the minimal parameters and generates
/// the rest.
///
/// this is a simpler version of [OidcAuthorizeRequest] and
/// [OidcTokenRequest] combined.
class OidcSimpleAuthorizationCodeFlowRequest {
  /// Creates a simple authorization code request.
  OidcSimpleAuthorizationCodeFlowRequest({
    required this.scope,
    required this.clientId,
    required this.redirectUri,
    this.managerId,
    this.originalUri,
    this.display,
    this.prompt,
    this.maxAge,
    this.uiLocales,
    this.idTokenHint,
    this.loginHint,
    this.acrValues,
    this.extraStateData,
    this.extraParameters,
    this.extraTokenParameters,
    this.extraTokenHeaders,
    this.options,
  });

  /// Arbitrary options that will be persisted in the state and roundtripped
  /// when the response is received.
  ///
  /// it MUST be json serializable.
  Map<String, dynamic>? options;

  /// The original uri to go back to after the authorization succeeds,
  /// if null, defaults to [redirectUri].
  Uri? originalUri;

  /// see [OidcAuthorizeState.extraTokenParams]
  Map<String, dynamic>? extraTokenParameters;

  /// see [OidcAuthorizeState.extraTokenHeaders]
  Map<String, String>? extraTokenHeaders;

  /// Extra state data that will be persisted and roundtripped when the response
  /// is received.
  ///
  /// it MUST be json serializable.
  dynamic extraStateData;

  /// see [OidcAuthorizeRequest.scope].
  List<String> scope;

  /// see [OidcAuthorizeRequest.clientId].
  String clientId;

  /// see [OidcAuthorizeRequest.redirectUri].
  Uri redirectUri;

  /// see [OidcAuthorizeRequest.display].
  String? display;

  /// see [OidcAuthorizeRequest.prompt].
  List<String>? prompt;

  /// see [OidcAuthorizeRequest.maxAge].
  Duration? maxAge;

  /// see [OidcAuthorizeRequest.uiLocales].
  List<String>? uiLocales;

  /// see [OidcAuthorizeRequest.idTokenHint].
  String? idTokenHint;

  /// see [OidcAuthorizeRequest.loginHint].
  String? loginHint;

  /// see [OidcAuthorizeRequest.acrValues].
  List<String>? acrValues;

  /// see [OidcAuthorizeRequest.extra].
  Map<String, dynamic>? extraParameters;

  /// The id of the manager that will handle this request.
  String? managerId;
}

/// The result of processing an [OidcSimpleAuthorizationCodeFlowRequest]
/// or [OidcSimpleImplicitFlowRequest].
class OidcSimpleAuthorizationRequestContainer {
  ///
  const OidcSimpleAuthorizationRequestContainer({
    required this.request,
    required this.stateData,
  });

  final OidcAuthorizeRequest request;
  final OidcAuthorizeState stateData;
}
