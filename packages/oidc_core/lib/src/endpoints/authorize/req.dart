import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

import 'package:oidc_core/src/models/json_based_object.dart';

part 'req.g.dart';

/// A class that describes an /authorize request.
///
/// Note: this class does NO special logic.
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcAuthorizeRequest extends JsonBasedRequest {
  /// Create an OidcAuthorizeRequest.
  OidcAuthorizeRequest({
    required this.responseType,
    required this.clientId,
    required this.redirectUri,
    required this.scope,
    this.extraScopeToConsent,
    this.codeChallenge,
    this.codeChallengeMethod,
    super.extra,
    this.prompt,
    this.state,
    this.responseMode,
    this.nonce,
    this.display,
    this.maxAge,
    this.uiLocales,
    this.idTokenHint,
    this.loginHint,
    this.acrValues,
  });

  /// REQUIRED.
  ///
  /// OpenID Connect requests MUST contain the openid scope value.
  ///
  /// If the "openid" scope value is not present,
  /// the behavior is entirely unspecified.
  ///
  /// Other scope values MAY be present.
  ///
  /// Scope values used that are not understood by an implementation
  /// SHOULD be ignored.
  ///
  /// See Sections [5.4](https://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims) and [11](https://openid.net/specs/openid-connect-core-1_0.html#OfflineAccess) for additional scope values defined
  /// by this specification.
  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String> scope;

  /// OPTIONAL.
  ///
  /// Will be requested to be consented by the user. Included in initial AuthorizationCodeFlowRequest but not in the Token request.
  List<String>? extraScopeToConsent;

  /// REQUIRED.
  ///
  /// OAuth 2.0 Response Type value that determines the authorization processing
  /// flow to be used, including what parameters are returned from the endpoints
  /// used.
  ///
  /// When using the Authorization Code Flow, this value is code.
  ///
  /// see [OidcConstants_AuthorizationEndpoint_ResponseType] for possible values
  @JsonKey(
    name: OidcConstants_AuthParameters.responseType,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String> responseType;

  /// REQUIRED.
  ///
  /// OAuth 2.0 Client Identifier valid at the Authorization Server.
  @JsonKey(name: OidcConstants_AuthParameters.clientId)
  String clientId;

  /// REQUIRED.
  ///
  /// Redirection URI to which the response will be sent.
  ///
  /// This URI MUST exactly match one of the Redirection URI values for the
  /// Client pre-registered at the OpenID Provider, with the matching performed
  /// as described in [Section 6.2.1 of RFC3986 (Simple String Comparison)](https://datatracker.ietf.org/doc/html/rfc3986#section-6.2.1).
  ///
  /// When using this flow, the Redirection URI SHOULD use the https scheme;
  /// however, it MAY use the http scheme, provided that the Client Type is
  /// confidential, as defined in Section 2.1 of OAuth 2.0, and provided the OP
  /// allows the use of http Redirection URIs in this case.
  ///
  /// The Redirection URI MAY use an alternate scheme, such as one that is
  /// intended to identify a callback into a native application.
  @JsonKey(name: OidcConstants_AuthParameters.redirectUri)
  Uri redirectUri;

  /// RECOMMENDED.
  ///
  /// Opaque value used to maintain state between the request and the callback.
  ///
  /// Typically, Cross-Site Request Forgery (CSRF, XSRF)
  /// mitigation is done by cryptographically binding
  /// the value of this parameter with a browser cookie.
  @JsonKey(name: OidcConstants_AuthParameters.state)
  String? state;

  ///OPTIONAL.
  ///
  ///Informs the Authorization Server of the mechanism to be used for returning
  ///parameters from the Authorization Endpoint.
  ///
  ///This use of this parameter is NOT RECOMMENDED when the Response Mode that
  ///would be requested is the default mode specified for the Response Type.
  ///
  ///the possible values are defined in
  ///[OidcConstants_AuthorizeRequest_ResponseMode].
  @JsonKey(name: OidcConstants_AuthParameters.responseMode)
  String? responseMode;

  /// OPTIONAL.
  ///
  /// String value used to associate a Client session with an ID Token,
  /// and to mitigate replay attacks.
  ///
  /// The value is passed through unmodified from the Authentication Request
  /// to the ID Token.
  ///
  /// Sufficient entropy MUST be present in the nonce values used to prevent
  /// attackers from guessing values. For implementation notes,
  /// see [Section 15.5.2](https://openid.net/specs/openid-connect-core-1_0.html#NonceNotes).
  @JsonKey(name: OidcConstants_AuthParameters.nonce)
  String? nonce;

  /// OPTIONAL.
  ///
  /// ASCII string value that specifies how the Authorization Server displays
  /// the authentication and consent user interface pages to the End-User.
  ///
  /// The defined values are in [OidcConstants_AuthorizeRequest_Display].
  ///
  /// The Authorization Server MAY also attempt to detect the capabilities of
  /// the User Agent and present an appropriate display.
  @JsonKey(name: OidcConstants_AuthParameters.display)
  String? display;

  /// OPTIONAL.
  ///
  /// Space delimited, case sensitive list of ASCII string values that specifies
  ///  whether the Authorization Server prompts the End-User
  /// for re-authentication and consent.
  ///
  /// The defined values are in [OidcConstants_AuthorizeRequest_Prompt]
  ///
  /// The prompt parameter can be used by the Client to make sure that the
  /// End-User is still present for the current session or to bring attention
  /// to the request.
  ///
  /// If this parameter contains none with any other value,
  /// an error is returned.
  @JsonKey(
    name: OidcConstants_AuthParameters.prompt,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String>? prompt;

  /// OPTIONAL.
  ///
  /// Maximum Authentication Age.
  ///
  /// Specifies the allowable elapsed time in seconds since the last time the
  /// End-User was actively authenticated by the OP.
  ///
  /// If the elapsed time is greater than this value, the OP MUST attempt to
  /// actively re-authenticate the End-User.
  ///
  /// The max_age request parameter corresponds to the
  /// [OpenID 2.0 PAPE max_auth_age request parameter](https://openid.net/specs/openid-provider-authentication-policy-extension-1_0.html#anchor8).
  ///
  /// When max_age is used, the ID Token returned MUST include an auth_time
  /// Claim Value.
  @JsonKey(name: OidcConstants_AuthParameters.maxAge)
  Duration? maxAge;

  /// OPTIONAL.
  ///
  /// End-User's preferred languages and scripts for the user interface,
  /// represented as a space-separated list of [BCP47 [RFC5646]](https://datatracker.ietf.org/doc/html/rfc5646) language tag values, ordered by preference.
  ///
  /// For instance, the value "fr-CA fr en" represents a preference for French
  /// as spoken in Canada, then French (without a region designation),
  /// followed by English (without a region designation).
  ///
  /// An error SHOULD NOT result if some or all of the requested locales
  /// are not supported by the OpenID Provider.
  @JsonKey(
    name: OidcConstants_AuthParameters.uiLocales,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String>? uiLocales;

  /// OPTIONAL.
  ///
  /// ID Token previously issued by the Authorization Server being passed as a
  /// hint about the End-User's current or past authenticated session with
  /// the Client.
  ///
  /// If the End-User identified by the ID Token is logged in or
  /// is logged in by the request, then the Authorization Server returns
  /// a positive response; otherwise, it SHOULD return an error,
  /// such as login_required.
  ///
  /// When possible, an id_token_hint SHOULD be present when prompt=none is
  /// used and an invalid_request error MAY be returned if it is not;
  /// however, the server SHOULD respond successfully when possible,
  /// even if it is not present.
  ///
  /// The Authorization Server need not be listed as an audience of the
  /// ID Token when it is used as an id_token_hint value.
  ///
  /// If the ID Token received by the RP from the OP is encrypted, to use it
  /// as an id_token_hint, the Client MUST decrypt the signed ID Token contained
  /// within the encrypted ID Token.
  ///
  /// The Client MAY re-encrypt the signed ID token to the Authentication Server
  /// using a key that enables the server to decrypt the ID Token, and use the
  /// re-encrypted ID token as the id_token_hint value.
  @JsonKey(name: OidcConstants_AuthParameters.idTokenHint)
  String? idTokenHint;

  /// OPTIONAL.
  ///
  /// Hint to the Authorization Server about the login identifier the End-User
  ///  might use to log in (if necessary).
  ///
  /// This hint can be used by an RP if it first asks the End-User for their
  /// e-mail address (or other identifier) and then wants to pass that value
  /// as a hint to the discovered authorization service.
  ///
  /// It is RECOMMENDED that the hint value match the value used for discovery.
  ///
  /// This value MAY also be a phone number in the format specified for the
  /// phone_number Claim.
  ///
  /// The use of this parameter is left to the OP's discretion.
  @JsonKey(name: OidcConstants_AuthParameters.loginHint)
  String? loginHint;

  /// OPTIONAL.
  ///
  /// Requested Authentication Context Class Reference values.
  ///
  /// Space-separated string that specifies the acr values that the
  /// Authorization Server is being requested to use for processing this
  /// Authentication Request, with the values appearing in order of preference.
  ///
  /// The Authentication Context Class satisfied by the authentication
  /// performed is returned as the acr Claim Value, as specified in [Section 2.2](https://openid.net/specs/openid-connect-basic-1_0.html#IDToken)
  ///
  /// The acr Claim is requested as a Voluntary Claim by this parameter.
  @JsonKey(
    name: OidcConstants_AuthParameters.acrValues,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  List<String>? acrValues;

  /// REQUIRED, when using PKCE Extension.
  ///
  /// Code challenge.
  @JsonKey(name: OidcConstants_AuthParameters.codeChallenge)
  String? codeChallenge;

  /// OPTIONAL, defaults to "plain" if not present in the request.
  ///
  /// Code verifier transformation method is "S256" or "plain".
  @JsonKey(name: OidcConstants_AuthParameters.codeChallengeMethod)
  String? codeChallengeMethod;

  /// converts the request into a JSON Map.
  @override
  Map<String, dynamic> toMap() => {
        ..._$OidcAuthorizeRequestToJson(this),
        ...super.toMap(),
      };

  Uri generateUri(Uri authorizationEndpoint) => authorizationEndpoint.replace(
        queryParameters: {
          ...authorizationEndpoint.queryParameters,
          ...OidcInternalUtilities.serializeQueryParameters(toMap()),
        },
      );
}
